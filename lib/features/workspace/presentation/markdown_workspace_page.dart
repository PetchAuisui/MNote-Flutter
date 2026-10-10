import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnote/features/workspace/data/device_image_picker.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/data/mermaid_file_source.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_formatting_toolbar.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';
import 'package:mnote/features/workspace/presentation/live_markdown_controller.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';
import 'package:scribble/scribble.dart';
import 'package:url_launcher/url_launcher.dart';
import 'markdown_live_editor.dart';
import 'markdown_document_style.dart';
import 'ink_page.dart';
import 'ink_session.dart';

class MarkdownWorkspacePage extends StatefulWidget {
  const MarkdownWorkspacePage({
    super.key,
    required this.repository,
    this.initialDocument,
    this.imagePicker = const DeviceImagePicker(),
    this.mermaidFileSource = const DeviceMermaidFileSource(),
    this.inkStorage = const DeviceInkFileStorage(),
  });

  final DocumentRepository repository;
  final MarkdownDocument? initialDocument;
  final DeviceImagePicker imagePicker;
  final MermaidFileSource mermaidFileSource;
  final InkFileStorage inkStorage;

  @override
  State<MarkdownWorkspacePage> createState() => _MarkdownWorkspacePageState();
}

class _MarkdownWorkspacePageState extends State<MarkdownWorkspacePage> {
  static const _editorTextStyle = TextStyle(
    fontSize: MarkdownDocumentStyle.bodySize,
    height: 1.55,
  );

  late final WorkspaceController _workspace;
  late final LiveMarkdownEditingController _textController;
  late final TextEditingController _titleController;
  late final ScrollController _editorScrollController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _markdownFocusNode;
  late UndoHistoryController _undoController;
  final _markdownHistory = MarkdownEditHistory();
  int _editorHistoryRevision = 0;
  bool _isEditingTitle = false;
  InkSession _ink = InkSession();
  late final TransformationController _inkTransform;
  InkTool _inkTool = InkTool.pen;
  Color _inkPenColor = const Color(0xFF202124);
  double _inkPenWidth = 3;
  bool _inkTouch = false;
  double _inkViewportWidth = 0;
  Future<void> _inkWrite = Future.value();
  // Ink is only written once the document's existing ink has been loaded (or
  // found missing/backed up), so autosave can never overwrite unread ink.
  bool _inkReady = false;
  int _inkLinesSeen = 0;

  @override
  void initState() {
    super.initState();
    _inkTransform = TransformationController();
    _ink.addListener(_scheduleInkSave);
    _workspace = WorkspaceController(
      widget.repository,
      initialDocument: widget.initialDocument,
    )..addListener(_onWorkspaceChanged);
    _textController = LiveMarkdownEditingController(
      text: _workspace.document.content,
      showRawSource: true,
    );
    _markdownFocusNode = FocusNode()..addListener(_onMarkdownFocusChanged);
    _titleController = TextEditingController(text: _workspace.document.name);
    _editorScrollController = ScrollController();
    _titleFocusNode = FocusNode()..addListener(_onTitleFocusChanged);
    _undoController = UndoHistoryController();
    _loadBundledExample();
    unawaited(_loadInk());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _textController.primaryColor = Theme.of(context).colorScheme.primary;
  }

  Future<void> _loadBundledExample() async {
    try {
      final content = await rootBundle.loadString('assets/examples/welcome.md');
      final previous = await rootBundle.loadString(
        'assets/examples/welcome_v1.md',
      );
      if (!mounted) return;
      if (!_workspace.upgradeExample(previous, content)) {
        _workspace.loadExample(content);
      }
    } catch (_) {
      // The editor remains usable as an empty document if the asset is missing.
    }
  }

  @override
  void dispose() {
    unawaited(_saveInk());
    _inkTransform.dispose();
    _ink
      ..removeListener(_scheduleInkSave)
      ..dispose();
    _workspace
      ..removeListener(_onWorkspaceChanged)
      ..dispose();
    _markdownFocusNode
      ..removeListener(_onMarkdownFocusChanged)
      ..dispose();
    _textController.dispose();
    _titleController.dispose();
    _editorScrollController.dispose();
    _undoController.dispose();
    _titleFocusNode
      ..removeListener(_onTitleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onWorkspaceChanged() {
    final content = _workspace.document.content;
    if (_textController.text != content) {
      _textController.value = TextEditingValue(
        text: content,
        selection: TextSelection.collapsed(offset: content.length),
      );
    }
    if (!_isEditingTitle && _titleController.text != _workspace.document.name) {
      _titleController.text = _workspace.document.name;
    }
    if (mounted) setState(() {});
  }

  void _onMarkdownFocusChanged() {
    _textController.editorHasFocus = _markdownFocusNode.hasFocus;
  }

  void _onTitleFocusChanged() {
    if (!_titleFocusNode.hasFocus && _isEditingTitle) {
      _finishEditingTitle();
    }
  }

  void _startEditingTitle() {
    setState(() => _isEditingTitle = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _titleFocusNode.requestFocus();
      final extensionStart = _titleController.text.lastIndexOf('.');
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: extensionStart > 0
            ? extensionStart
            : _titleController.text.length,
      );
    });
  }

  void _finishEditingTitle() {
    if (!_isEditingTitle) return;
    final name = _normalizedDocumentName(_titleController.text);
    setState(() => _isEditingTitle = false);
    _workspace.updateName(name);
    _titleController.text = _workspace.document.name;
    _titleFocusNode.unfocus();
  }

  String _normalizedDocumentName(String value) {
    final name = value.trim();
    if (name.isEmpty) return _workspace.document.name;
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.md') ||
        lowerName.endsWith('.markdown') ||
        lowerName.endsWith('.txt')) {
      return name;
    }
    return '$name.md';
  }

  Future<bool> _confirmDiscardChanges() async {
    // Let an autosave that is still writing finish, so it is not mistaken for
    // unsaved ink.
    await _inkWrite;
    if (!mounted) return false;
    if (!_workspace.document.isDirty && !_ink.isDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded),
            title: const Text('ละทิ้งการแก้ไข?'),
            content: const Text('การเปลี่ยนแปลงที่ยังไม่ได้บันทึกจะหายไป'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ละทิ้ง'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openDocument() async {
    if (!await _confirmDiscardChanges()) return;
    await _saveInk();
    final opened = await _runFileAction(
      _workspace.openDocument,
      successMessage: 'เปิดเอกสารแล้ว',
    );
    if (opened) {
      _resetInk();
      _resetUndoHistory();
      unawaited(_loadInk());
    }
  }

  Future<void> _newDocument() async {
    if (!await _confirmDiscardChanges()) return;
    await _saveInk();
    _workspace.newDocument();
    _resetInk();
    _resetUndoHistory();
    _inkReady = true;
  }

  Future<void> _saveDocument({bool saveAs = false}) async {
    await _runFileAction(
      saveAs ? _workspace.saveAs : _workspace.save,
      successMessage: 'บันทึกเอกสารแล้ว',
    );
    // A new location needs its own ink file even if the ink itself is clean.
    unawaited(_saveInk(force: true));
  }

  void _resetInk() {
    final previous = _ink..removeListener(_scheduleInkSave);
    _inkReady = false;
    _inkLinesSeen = 0;
    setState(() => _ink = InkSession()..addListener(_scheduleInkSave));
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  Future<bool> _runFileAction(
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    final succeeded = await action();
    if (!mounted) return succeeded;
    final error = _workspace.errorMessage;
    if (error != null) {
      _workspace.clearError();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else if (succeeded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    }
    return succeeded;
  }

  void _resetUndoHistory() {
    _markdownHistory.clear();
    final previousController = _undoController;
    _undoController = UndoHistoryController();
    _editorHistoryRevision += 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previousController.dispose();
    });
    if (mounted) setState(() {});
  }

  void _replaceSelection(
    String prefix,
    String suffix, {
    required String placeholder,
  }) {
    final value = _textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final selected = selection.textInside(value.text);
    final body = selected.isEmpty ? placeholder : selected;
    final replacement = '$prefix$body$suffix';
    final nextText = value.text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );
    final bodyStart = selection.start + prefix.length;
    final nextSelection = selected.isEmpty
        ? TextSelection(
            baseOffset: bodyStart,
            extentOffset: bodyStart + body.length,
          )
        : TextSelection.collapsed(offset: selection.start + replacement.length);

    _textController.value = TextEditingValue(
      text: nextText,
      selection: nextSelection,
    );
    _workspace.updateContent(nextText);
  }

  void _toggleInlineFormat(
    String prefix,
    String suffix, {
    required String placeholder,
  }) {
    final value = _textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = selection.start;
    final end = selection.end;
    final selected = selection.textInside(value.text);

    if (selected.isNotEmpty &&
        selected.startsWith(prefix) &&
        selected.endsWith(suffix) &&
        selected.length >= prefix.length + suffix.length) {
      final body = selected.substring(
        prefix.length,
        selected.length - suffix.length,
      );
      _applyTextEdit(
        value.text.replaceRange(start, end, body),
        TextSelection(baseOffset: start, extentOffset: start + body.length),
      );
      return;
    }

    final hasSurroundingMarkers =
        start >= prefix.length &&
        end + suffix.length <= value.text.length &&
        value.text.substring(start - prefix.length, start) == prefix &&
        value.text.substring(end, end + suffix.length) == suffix;
    if (hasSurroundingMarkers) {
      final nextText = value.text.replaceRange(
        start - prefix.length,
        end + suffix.length,
        selected,
      );
      _applyTextEdit(
        nextText,
        TextSelection(
          baseOffset: start - prefix.length,
          extentOffset: end - prefix.length,
        ),
      );
      return;
    }

    _replaceSelection(prefix, suffix, placeholder: placeholder);
  }

  void _formatSelectedLines({
    required String Function(int index) prefixBuilder,
    required String placeholder,
    required Pattern removePattern,
    bool toggle = true,
  }) {
    final value = _textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = selection.start;
    final end = selection.end;
    final lineStart = start == 0
        ? 0
        : value.text.lastIndexOf('\n', start - 1) + 1;
    final nextLineBreak = value.text.indexOf('\n', end);
    final lineEnd = nextLineBreak == -1 ? value.text.length : nextLineBreak;
    final block = value.text.substring(lineStart, lineEnd);
    final source = block.isEmpty ? placeholder : block;
    final lines = source.split('\n');
    final shouldRemove =
        toggle && lines.every((line) => line.startsWith(removePattern));
    final replacement = lines
        .asMap()
        .entries
        .map((entry) {
          final line = entry.value;
          if (shouldRemove) return line.replaceFirst(removePattern, '');
          final cleanLine = line.replaceFirst(removePattern, '');
          return '${prefixBuilder(entry.key)}$cleanLine';
        })
        .join('\n');

    _applyTextEdit(
      value.text.replaceRange(lineStart, lineEnd, replacement),
      TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replacement.length,
      ),
    );
  }

  void _applyHeading(int level) {
    _formatSelectedLines(
      prefixBuilder: (_) => '${'#' * level} ',
      placeholder: 'หัวข้อ',
      removePattern: RegExp(r'^#{1,6}\s+'),
      toggle: false,
    );
  }

  void _formatOrderedList() {
    _formatSelectedLines(
      prefixBuilder: (index) => '${index + 1}. ',
      placeholder: 'รายการ',
      removePattern: RegExp(r'^\d+\.\s+'),
    );
  }

  void _changeListIndent({required bool increase}) {
    final value = _textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = selection.start;
    final end = selection.end;
    final lineStart = start == 0
        ? 0
        : value.text.lastIndexOf('\n', start - 1) + 1;
    final nextLineBreak = value.text.indexOf('\n', end);
    final lineEnd = nextLineBreak == -1 ? value.text.length : nextLineBreak;
    final block = value.text.substring(lineStart, lineEnd);
    final replacement = block
        .split('\n')
        .map(
          (line) => increase
              ? '  $line'
              : line.replaceFirst(RegExp(r'^( {1,2}|\t)'), ''),
        )
        .join('\n');

    _applyTextEdit(
      value.text.replaceRange(lineStart, lineEnd, replacement),
      TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replacement.length,
      ),
    );
  }

  void _insertCodeBlock() {
    final value = _textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final selected = selection.textInside(value.text);
    final body = selected.isEmpty ? 'code' : selected;
    final leadingBreak =
        selection.start > 0 && value.text[selection.start - 1] != '\n'
        ? '\n'
        : '';
    final trailingBreak =
        selection.end < value.text.length && value.text[selection.end] != '\n'
        ? '\n'
        : '';
    final replacement = '$leadingBreak```\n$body\n```$trailingBreak';
    final bodyStart = selection.start + leadingBreak.length + 4;
    _applyTextEdit(
      value.text.replaceRange(selection.start, selection.end, replacement),
      TextSelection(
        baseOffset: bodyStart,
        extentOffset: bodyStart + body.length,
      ),
    );
  }

  Future<void> _insertTable() async {
    var rows = 2;
    var columns = 2;
    final size = await showDialog<(int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('แทรกตาราง'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                key: const Key('table-columns'),
                initialValue: columns,
                decoration: const InputDecoration(labelText: 'จำนวนคอลัมน์'),
                items: [
                  for (var count = 1; count <= 8; count++)
                    DropdownMenuItem(value: count, child: Text('$count')),
                ],
                onChanged: (value) => update(() => columns = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('table-rows'),
                initialValue: rows,
                decoration: const InputDecoration(labelText: 'จำนวนแถวข้อมูล'),
                items: [
                  for (var count = 1; count <= 10; count++)
                    DropdownMenuItem(value: count, child: Text('$count')),
                ],
                onChanged: (value) => update(() => rows = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              key: const Key('insert-table-confirm'),
              onPressed: () => Navigator.pop(context, (rows, columns)),
              child: const Text('แทรก'),
            ),
          ],
        ),
      ),
    );
    if (size == null || !mounted) return;
    final value = _textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    String row(List<String> cells) => '| ${cells.join(' | ')} |';
    final table = [
      row(List.generate(size.$2, (index) => 'หัวข้อ ${index + 1}')),
      row(List.filled(size.$2, '---')),
      for (var index = 0; index < size.$1; index++)
        row(List.filled(size.$2, 'ข้อมูล')),
    ].join('\n');
    final leading = selection.start > 0 ? '\n\n' : '';
    final replacement = '$leading$table\n\n';
    _applyTextEdit(
      value.text.replaceRange(selection.start, selection.end, replacement),
      TextSelection.collapsed(
        offset: selection.start + leading.length + table.length,
      ),
    );
  }

  void _insertLineBreak() {
    _insertAtSelectionEnd('<br>\n');
  }

  void _insertHorizontalRule() {
    final value = _textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final offset = selection.end;
    final leadingBreak = offset > 0 && value.text[offset - 1] != '\n'
        ? '\n'
        : '';
    final trailingBreak =
        offset < value.text.length && value.text[offset] != '\n' ? '\n' : '';
    _insertAtSelectionEnd('$leadingBreak---\n$trailingBreak');
  }

  void _insertDiagramTemplate(MermaidTemplate template) {
    final value = _textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final offset = selection.end;
    final leadingBreak = offset > 0 && value.text[offset - 1] != '\n'
        ? '\n'
        : '';
    final trailingBreak =
        offset < value.text.length && value.text[offset] != '\n' ? '\n' : '';
    _insertAtSelectionEnd(
      '$leadingBreak${buildMermaidFencedBlock(template.source)}\n'
      '$trailingBreak',
    );
  }

  Future<void> _importDiagramFile() async {
    final PickedMermaidFile? picked;
    try {
      picked = await widget.mermaidFileSource.pick(
        maxBytes: mermaidImportMaxBytes,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดไฟล์ไม่สำเร็จ กรุณาลองใหม่')),
      );
      return;
    }
    if (picked == null || !mounted) return;
    switch (parseMermaidImport(name: picked.name, bytes: picked.bytes)) {
      case MermaidImportFailure(:final message):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      case MermaidImportSuccess(:final name, :final source):
        await showMermaidImportDialog(context, fileName: name, source: source);
    }
  }

  void _insertAtSelectionEnd(String token) {
    final value = _textController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final offset = selection.end;
    final nextText = value.text.replaceRange(offset, offset, token);
    _applyTextEdit(
      nextText,
      TextSelection.collapsed(offset: offset + token.length),
    );
  }

  void _applyTextEdit(String text, TextSelection selection) {
    _textController.value = TextEditingValue(text: text, selection: selection);
    _workspace.updateContent(text);
  }

  Future<void> _insertImage() async {
    final image = await widget.imagePicker.pick();
    if (image == null || !mounted) return;
    _replaceSelection('', '', placeholder: image.markdown);
  }

  bool get _isTextMode =>
      _workspace.mode == WorkspaceMode.edit ||
      _workspace.mode == WorkspaceMode.split;

  /// Formatting shortcuts act on the document body, not on the title field.
  VoidCallback _unlessTitleFocused(VoidCallback action) => () {
    if (!_titleFocusNode.hasFocus) action();
  };

  Map<ShortcutActivator, VoidCallback> get _formattingShortcuts => {
    for (final control in [true, false]) ...{
      SingleActivator(
        LogicalKeyboardKey.keyB,
        control: control,
        meta: !control,
      ): _unlessTitleFocused(
        () => _toggleInlineFormat('**', '**', placeholder: 'ข้อความตัวหนา'),
      ),
      SingleActivator(
        LogicalKeyboardKey.keyI,
        control: control,
        meta: !control,
      ): _unlessTitleFocused(
        () => _toggleInlineFormat('_', '_', placeholder: 'ข้อความตัวเอียง'),
      ),
      SingleActivator(
        LogicalKeyboardKey.keyE,
        control: control,
        meta: !control,
      ): _unlessTitleFocused(
        () => _toggleInlineFormat('`', '`', placeholder: 'code'),
      ),
      SingleActivator(
        LogicalKeyboardKey.keyK,
        control: control,
        meta: !control,
      ): _unlessTitleFocused(
        () => _replaceSelection('[', '](https://)', placeholder: 'ชื่อลิงก์'),
      ),
      SingleActivator(
        LogicalKeyboardKey.keyX,
        control: control,
        meta: !control,
        shift: true,
      ): _unlessTitleFocused(
        () => _toggleInlineFormat('~~', '~~', placeholder: 'ข้อความขีดฆ่า'),
      ),
    },
  };

  Future<void> _openLink(String? href) async {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null || !await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่สามารถเปิดลิงก์นี้ได้')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = _workspace.document;
    return PopScope<MarkdownDocument>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardChanges();
        if (shouldPop && context.mounted) {
          Navigator.of(
            context,
          ).pop(_workspace.document.isDirty ? null : _workspace.document);
        }
      },
      child: CallbackShortcuts(
        bindings: _isTextMode ? _formattingShortcuts : const {},
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (_workspace.isBusy)
                  const LinearProgressIndicator(minHeight: 2),
                _buildWorkspaceHeader(document),
                if (_workspace.mode == WorkspaceMode.edit ||
                    _workspace.mode == WorkspaceMode.split)
                  _buildFormattingToolbar()
                else if (_workspace.mode == WorkspaceMode.ink)
                  _buildInkToolbar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Card(
                      key: const Key('document-surface'),
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: Colors.white,
                      shape: const RoundedRectangleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Expanded(
                            child: _workspace.mode == WorkspaceMode.edit
                                ? _buildEditor()
                                : _workspace.mode == WorkspaceMode.split
                                ? _buildSplitView()
                                : _workspace.mode == WorkspaceMode.ink
                                ? InkPage(
                                    key: ObjectKey(_ink),
                                    session: _ink,
                                    markdown: document.content,
                                    imageDirectory: _imageDirectory,
                                    transformationController: _inkTransform,
                                    showToolbar: false,
                                    onViewportWidthChanged: (w) =>
                                        _inkViewportWidth = w,
                                  )
                                : _buildPreview(),
                          ),
                          const Divider(height: 1),
                          Container(
                            width: double.infinity,
                            color: const Color(0xFFECEEF3),
                            padding: const EdgeInsets.fromLTRB(16, 8, 32, 10),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _workspace.mode == WorkspaceMode.split
                                    ? 'เขียนพร้อมแสดงผล · ${document.content.split('\n').length} บรรทัด · ${document.content.characters.length} ตัวอักษร'
                                    : '${document.content.split('\n').length} บรรทัด · ${document.content.characters.length} ตัวอักษร',
                                key: const Key('document-statistics'),
                                maxLines: 1,
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: const Color(0xFF5F6368)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitView() => MarkdownLiveEditor(
    history: _markdownHistory,
    onTapLink: (text, href, title) => _openLink(href),
    undoController: _undoController,
    controller: _textController,
    onChanged: _workspace.updateContent,
    imageDirectory: _imageDirectory,
    builders: {'code': MermaidElementBuilder()},
  );

  Widget _buildWorkspaceHeader(MarkdownDocument document) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('workspace-header'),
      color: colorScheme.surfaceContainerLowest,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final title = _buildDocumentTitle(document);
          final modes = _buildModeSwitcher(compact: !wide);
          final actions = _buildDocumentActions();
          if (!wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (Navigator.canPop(context))
                          BackButton(
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        Expanded(child: title),
                        actions,
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  modes,
                ],
              ),
            );
          }
          final centerGap = constraints.maxWidth >= 960 ? 430.0 : 380.0;
          return SizedBox(
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (Navigator.canPop(context)) ...[
                        BackButton(
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: title,
                        ),
                      ),
                      SizedBox(width: centerGap),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: actions,
                        ),
                      ),
                    ],
                  ),
                ),
                modes,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentTitle(MarkdownDocument document) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEditingTitle)
            TextField(
              key: const Key('document-title-field'),
              controller: _titleController,
              focusNode: _titleFocusNode,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              style: Theme.of(context).textTheme.titleMedium,
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _finishEditingTitle(),
              onTapOutside: (_) => _finishEditingTitle(),
            )
          else
            Tooltip(
              message: 'แก้ไขชื่อเอกสาร',
              child: InkWell(
                key: const Key('document-title'),
                borderRadius: BorderRadius.circular(8),
                onTap: _startEditingTitle,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        document.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          Text(
            _statusLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher({required bool compact}) {
    return SegmentedButton<WorkspaceMode>(
      key: const Key('workspace-mode-switcher'),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      ),
      segments: [
        ButtonSegment(
          value: WorkspaceMode.split,
          icon: const Icon(Icons.edit_document),
          label: compact ? null : const Text('Markdown'),
          tooltip: 'Markdown',
        ),
        ButtonSegment(
          value: WorkspaceMode.ink,
          icon: const Icon(Icons.draw_outlined),
          label: compact ? null : const Text('เขียน'),
          tooltip: 'เขียน',
        ),
      ],
      selected: {_workspace.mode},
      onSelectionChanged: (selection) {
        _workspace.setMode(selection.first);
        if (selection.first == WorkspaceMode.ink) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitInk();
          });
        }
      },
    );
  }

  Widget _buildDocumentActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _workspace.isBusy ? null : _openDocument,
          visualDensity: VisualDensity.compact,
          tooltip: 'เปิดไฟล์',
          icon: const Icon(Icons.folder_open_rounded),
        ),
        IconButton.filledTonal(
          onPressed: _workspace.isBusy ? null : _saveDocument,
          visualDensity: VisualDensity.compact,
          tooltip: 'บันทึก',
          icon: const Icon(Icons.save_rounded),
        ),
        PopupMenuButton<_DocumentAction>(
          iconSize: 24,
          padding: const EdgeInsets.all(8),
          tooltip: 'คำสั่งเพิ่มเติม',
          onSelected: (action) {
            switch (action) {
              case _DocumentAction.newDocument:
                _newDocument();
              case _DocumentAction.saveAs:
                _saveDocument(saveAs: true);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _DocumentAction.newDocument,
              child: ListTile(
                leading: Icon(Icons.note_add_outlined),
                title: Text('เอกสารใหม่'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _DocumentAction.saveAs,
              child: ListTile(
                leading: Icon(Icons.save_as_outlined),
                title: Text('บันทึกเป็น'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String get _statusLabel {
    if (_workspace.isBusy) return 'กำลังดำเนินการ…';
    if (_workspace.document.isDirty) return 'ยังไม่ได้บันทึก';
    if (_workspace.document.name == 'Welcome.md' &&
        _workspace.document.uri == null) {
      return 'เอกสารตัวอย่าง · พร้อมแก้ไข';
    }
    if (_workspace.document.uri == null) return 'เอกสารใหม่';
    return 'บันทึกแล้ว';
  }

  Widget _buildFormattingToolbar() {
    return ValueListenableBuilder<UndoHistoryValue>(
      valueListenable: _undoController,
      builder: (context, history, _) => MarkdownFormattingToolbar(
        onUndo: history.canUndo ? _undoController.undo : null,
        onRedo: history.canRedo ? _undoController.redo : null,
        onHeading: _applyHeading,
        onBold: () =>
            _toggleInlineFormat('**', '**', placeholder: 'ข้อความตัวหนา'),
        onItalic: () =>
            _toggleInlineFormat('_', '_', placeholder: 'ข้อความตัวเอียง'),
        onStrikethrough: () =>
            _toggleInlineFormat('~~', '~~', placeholder: 'ข้อความขีดฆ่า'),
        onList: () => _formatSelectedLines(
          prefixBuilder: (_) => '- ',
          placeholder: 'รายการ',
          removePattern: '- ',
        ),
        onOrderedList: _formatOrderedList,
        onTaskList: () => _formatSelectedLines(
          prefixBuilder: (_) => '- [ ] ',
          placeholder: 'งานที่ต้องทำ',
          removePattern: RegExp(r'^- \[[ xX]\] '),
        ),
        onIndentList: () => _changeListIndent(increase: true),
        onOutdentList: () => _changeListIndent(increase: false),
        onQuote: () => _formatSelectedLines(
          prefixBuilder: (_) => '> ',
          placeholder: 'ข้อความอ้างอิง',
          removePattern: '> ',
        ),
        onLineBreak: _insertLineBreak,
        onHorizontalRule: _insertHorizontalRule,
        onInlineCode: () => _toggleInlineFormat('`', '`', placeholder: 'code'),
        onCodeBlock: _insertCodeBlock,
        onDiagramTemplate: _insertDiagramTemplate,
        onImportDiagram: _importDiagramFile,
        onLink: () =>
            _replaceSelection('[', '](https://)', placeholder: 'ชื่อลิงก์'),
        onImage: _insertImage,
        onTable: _insertTable,
      ),
    );
  }

  void _fitInk() {
    final scale = (_inkViewportWidth / InkSession.pageWidth).clamp(0.1, 1.0);
    final dx = _inkViewportWidth > InkSession.pageWidth
        ? (_inkViewportWidth - InkSession.pageWidth) / 2
        : 0.0;
    _inkTransform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(dx, 0, 0);
  }

  void _selectInkTool(InkTool tool) {
    setState(() => _inkTool = tool);
    final pen = _ink.pen;
    switch (tool) {
      case InkTool.pen:
        pen
          ..setColor(_inkPenColor)
          ..setStrokeWidth(_inkPenWidth);
      case InkTool.highlighter:
        pen
          ..setColor(InkSession.highlightInk(_ink.highlightColor))
          ..setStrokeWidth(_ink.highlightWidth);
      case InkTool.eraser:
        pen
          ..setEraser()
          ..setStrokeWidth(28);
    }
  }

  void _selectInkColor(Color color) {
    if (_inkTool == InkTool.highlighter) {
      _ink.selectHighlight(color: color);
      _ink.pen.setColor(InkSession.highlightInk(color));
      return;
    }
    setState(() {
      _inkPenColor = color;
      _inkTool = InkTool.pen;
    });
    _ink.pen
      ..setColor(color)
      ..setStrokeWidth(_inkPenWidth);
  }

  void _selectInkWidth(double width) {
    if (_inkTool == InkTool.highlighter) {
      _ink.selectHighlight(width: width);
      _ink.pen.setStrokeWidth(width);
      return;
    }
    setState(() {
      _inkPenWidth = width;
      _inkTool = InkTool.pen;
    });
    _ink.pen
      ..setColor(_inkPenColor)
      ..setStrokeWidth(width);
  }

  void _toggleInkTouch() {
    setState(() => _inkTouch = !_inkTouch);
    _ink.pen.setAllowedPointersMode(
      _inkTouch ? ScribblePointerMode.all : ScribblePointerMode.penOnly,
    );
  }

  Future<void> _clearInk() async {
    if (_ink.pen.currentSketch.lines.isEmpty) return;
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('ล้างหมึกทั้งหมด?'),
        content: const Text('สามารถกดย้อนกลับได้หลังจากล้าง'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ล้างทั้งหมด'),
          ),
        ],
      ),
    );
    if (clear == true) _ink.pen.clear();
  }

  /// Ink autosaves next to the Markdown file as soon as a stroke is finished;
  /// a document that has no file yet keeps its ink in memory until it is first
  /// saved.
  void _scheduleInkSave() {
    // Only react when strokes are added or removed (stroke end, erase, undo,
    // redo, clear), not on every pointer move: the eraser rebuilds the sketch
    // on each move, so object identity would not be enough.
    final lines = _ink.pen.currentSketch.lines.length;
    if (lines == _inkLinesSeen) return;
    _inkLinesSeen = lines;
    unawaited(_saveInk());
  }

  /// Writes are queued so a slow write never overlaps (and is never overtaken
  /// by) a later one. [force] also writes clean, non-empty ink, e.g. after
  /// Save As.
  Future<void> _saveInk({bool force = false}) {
    final uri = _workspace.document.uri;
    final session = _ink;
    if (uri == null || !_inkReady) return _inkWrite;
    return _inkWrite = _inkWrite.then((_) async {
      // Nothing here may throw: a failed link would stop every later save.
      try {
        final empty = session.pen.currentSketch.lines.isEmpty;
        if (!session.isDirty && (!force || empty)) return;
        final snapshot = session.encode();
        await widget.inkStorage.write(uri, snapshot);
        session.markSaved(snapshot);
      } catch (_) {
        // The next stroke retries; the ink stays in memory meanwhile.
      }
    });
  }

  Future<void> _loadInk() async {
    final uri = _workspace.document.uri;
    final session = _ink;
    var safeToSave = true;
    try {
      if (uri != null) {
        final source = await widget.inkStorage.read(uri);
        if (!mounted || session != _ink) return;
        if (source != null) session.load(source);
      }
    } catch (_) {
      // An unreadable ink file leaves the page blank rather than blocking it;
      // keep the file aside so the first new stroke does not overwrite it. If
      // it cannot be kept, ink stays unsaved rather than replacing the file.
      try {
        await widget.inkStorage.backup(uri!);
      } catch (_) {
        safeToSave = false;
      }
    }
    if (safeToSave && mounted && session == _ink) _inkReady = true;
  }

  Widget _buildInkToolbar() {
    return ListenableBuilder(
      listenable: _ink,
      builder: (context, _) => InkToolbar(
        selectedTool: _inkTool,
        penColor: _inkTool == InkTool.highlighter
            ? _ink.highlightColor
            : _inkPenColor,
        penWidth: _inkTool == InkTool.highlighter
            ? _ink.highlightWidth
            : _inkPenWidth,
        touchEnabled: _inkTouch,
        onToolSelected: _selectInkTool,
        onColorSelected: _selectInkColor,
        onWidthSelected: _selectInkWidth,
        colorPresets: _inkTool == InkTool.highlighter
            ? _ink.highlightPresets
            : _ink.colorPresets,
        widthPresets: _inkTool == InkTool.highlighter
            ? _ink.highlightWidthPresets
            : _ink.widthPresets,
        onColorPresetChanged: _inkTool == InkTool.highlighter
            ? _ink.setHighlightPreset
            : _ink.setColorPreset,
        onWidthPresetChanged: _inkTool == InkTool.highlighter
            ? _ink.setHighlightWidthPreset
            : _ink.setWidthPreset,
        onUndo: _ink.pen.canUndo ? _ink.pen.undo : null,
        onRedo: _ink.pen.canRedo ? _ink.pen.redo : null,
        onClear: _ink.pen.currentSketch.lines.isEmpty ? null : _clearInk,
        onTouchChanged: _toggleInkTouch,
        onFit: _fitInk,
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pageTheme = ThemeData.light(useMaterial3: true);
          final colorScheme = pageTheme.colorScheme;
          final textScaler = MediaQuery.textScalerOf(context);
          final editorStyle = Theme.of(context).textTheme.bodyLarge!
              .merge(_editorTextStyle)
              .copyWith(color: const Color(0xFF202124));
          final lineCount = '\n'.allMatches(_textController.text).length + 1;
          // Reserve at least 3 digits so the text doesn't shift sideways when
          // the line count crosses 10 or 100.
          final gutterDigits = lineCount.toString().length.clamp(3, 99);
          final gutterWidth = 28.0 + gutterDigits * 8.0;
          const horizontalTextPadding = 28.0;
          final textWidth =
              (constraints.maxWidth - gutterWidth - horizontalTextPadding)
                  .clamp(1.0, double.infinity);

          return KeyedSubtree(
            key: ValueKey(_editorHistoryRevision),
            child: DecoratedBox(
              key: const Key('markdown-editor-page'),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    left: gutterWidth + 12,
                    top: 16,
                    right: 16,
                    bottom: 16,
                    child: TextField(
                      key: const Key('markdown-editor'),
                      focusNode: _markdownFocusNode,
                      controller: _textController,
                      undoController: _undoController,
                      scrollController: _editorScrollController,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      style: editorStyle,
                      strutStyle: StrutStyle.fromTextStyle(editorStyle),
                      decoration: null,
                      onChanged: _workspace.updateContent,
                    ),
                  ),
                  if (_textController.text.isEmpty)
                    Positioned(
                      left: gutterWidth + 12,
                      top: 16,
                      right: 16,
                      child: IgnorePointer(
                        child: Text(
                          'Read Markdown. Write freely.',
                          style: editorStyle.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: gutterWidth,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                      child: Semantics(
                        label: lineCount == 1
                            ? 'เลขบรรทัด 1'
                            : 'เลขบรรทัด 1 ถึง $lineCount',
                        child: CustomPaint(
                          key: const Key('line-number-gutter'),
                          painter: _LineNumberPainter(
                            textController: _textController,
                            editorStyle: editorStyle,
                            numberStyle: editorStyle.copyWith(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            activeNumberColor: colorScheme.primary,
                            backgroundColor: Colors.white,
                            dividerColor: colorScheme.outlineVariant,
                            textWidth: textWidth,
                            textScaler: textScaler,
                            scrollController: _editorScrollController,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreview() {
    return MarkdownPreviewCanvas(
      markdown: _workspace.document.content,
      height: _ink.height,
      imageDirectory: _imageDirectory,
      onTapLink: (text, href, title) => _openLink(href),
      builders: {'code': MermaidElementBuilder()},
    );
  }

  String? get _imageDirectory {
    final uri = _workspace.document.uri;
    if (uri == null || uri.scheme != 'file') return null;
    return uri.resolve('.').toString();
  }
}

enum _DocumentAction { newDocument, saveAs }

class _LineNumberPainter extends CustomPainter {
  _LineNumberPainter({
    required this.textController,
    required this.editorStyle,
    required this.numberStyle,
    required this.activeNumberColor,
    required this.backgroundColor,
    required this.dividerColor,
    required this.textWidth,
    required this.textScaler,
    required this.scrollController,
  }) : super(repaint: Listenable.merge([textController, scrollController]));

  final TextEditingController textController;
  final TextStyle editorStyle;
  final TextStyle numberStyle;
  final Color activeNumberColor;
  final Color backgroundColor;
  final Color dividerColor;
  final double textWidth;
  final TextScaler textScaler;
  final ScrollController scrollController;

  static const _topPadding = 16.0;
  static const _rightPadding = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(backgroundColor, BlendMode.src);
    canvas.drawLine(
      Offset(size.width - 0.5, 0),
      Offset(size.width - 0.5, size.height),
      Paint()
        ..color = dividerColor
        ..strokeWidth = 1,
    );

    final lines = textController.text.split('\n');
    final activeLine = _activeLine;
    var lineTop = _topPadding - _scrollOffset;

    for (var index = 0; index < lines.length; index++) {
      final lineStyle =
          (textController is LiveMarkdownEditingController &&
              (textController as LiveMarkdownEditingController).showRawSource)
          ? editorStyle
          : _headingStyleForLine(lines[index], editorStyle);
      final editorPainter = _textPainter(
        lines[index].isEmpty ? ' ' : lines[index],
        lineStyle,
      )..layout(maxWidth: textWidth);
      final editorMetrics = editorPainter.computeLineMetrics();
      final editorBaseline = editorMetrics.isEmpty
          ? editorPainter.height
          : editorMetrics.first.baseline;

      final numberPainter = _textPainter(
        '${index + 1}',
        index == activeLine
            ? numberStyle.copyWith(
                color: activeNumberColor,
                fontWeight: FontWeight.w700,
              )
            : numberStyle,
      )..layout();
      final numberMetrics = numberPainter.computeLineMetrics();
      final numberBaseline = numberMetrics.isEmpty
          ? numberPainter.height
          : numberMetrics.first.baseline;

      if (lineTop + editorPainter.height >= 0 && lineTop <= size.height) {
        numberPainter.paint(
          canvas,
          Offset(
            size.width - _rightPadding - numberPainter.width,
            lineTop + editorBaseline - numberBaseline,
          ),
        );
      }
      lineTop += editorPainter.height;
    }
  }

  TextPainter _textPainter(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      strutStyle: StrutStyle.fromTextStyle(style),
    );
  }

  int get _activeLine {
    final content = textController.text;
    final selection = textController.selection;
    final offset = selection.isValid
        ? selection.extentOffset.clamp(0, content.length)
        : content.length;
    return '\n'.allMatches(content.substring(0, offset)).length;
  }

  double get _scrollOffset {
    if (!scrollController.hasClients ||
        scrollController.positions.length != 1) {
      return 0;
    }
    return scrollController.offset;
  }

  static TextStyle _headingStyleForLine(String line, TextStyle baseStyle) {
    if (line.startsWith('#')) {
      final match = RegExp(r'^(#{1,6})\s+').firstMatch(line);
      if (match != null) {
        final level = match.group(1)!.length;
        final double factor;
        switch (level) {
          case 1:
            factor = 28 / 17;
            break;
          case 2:
            factor = 24 / 17;
            break;
          case 3:
            factor = 20 / 17;
            break;
          default:
            factor = MarkdownDocumentStyle.headingSizes[level - 1] / 17;
            break;
        }
        return baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 15) * factor,
          fontWeight: FontWeight.bold,
        );
      }
    }
    return baseStyle;
  }

  @override
  bool shouldRepaint(covariant _LineNumberPainter oldDelegate) {
    return textController != oldDelegate.textController ||
        editorStyle != oldDelegate.editorStyle ||
        numberStyle != oldDelegate.numberStyle ||
        activeNumberColor != oldDelegate.activeNumberColor ||
        backgroundColor != oldDelegate.backgroundColor ||
        dividerColor != oldDelegate.dividerColor ||
        textWidth != oldDelegate.textWidth ||
        textScaler != oldDelegate.textScaler;
  }
}
