import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnote/features/workspace/data/device_image_picker.dart';
import 'package:mnote/features/workspace/data/mermaid_file_source.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_formatting_toolbar.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_canvas.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ink_page.dart';
import 'ink_session.dart';

class MarkdownWorkspacePage extends StatefulWidget {
  const MarkdownWorkspacePage({
    super.key,
    required this.repository,
    this.initialDocument,
    this.imagePicker = const DeviceImagePicker(),
    this.mermaidFileSource = const DeviceMermaidFileSource(),
  });

  final DocumentRepository repository;
  final MarkdownDocument? initialDocument;
  final DeviceImagePicker imagePicker;
  final MermaidFileSource mermaidFileSource;

  @override
  State<MarkdownWorkspacePage> createState() => _MarkdownWorkspacePageState();
}

class _MarkdownWorkspacePageState extends State<MarkdownWorkspacePage> {
  static const _editorTextStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 15,
    height: 1.55,
  );

  late final WorkspaceController _workspace;
  late final TextEditingController _textController;
  late final TextEditingController _titleController;
  late final ScrollController _editorScrollController;
  late final FocusNode _titleFocusNode;
  late UndoHistoryController _undoController;
  int _editorHistoryRevision = 0;
  bool _isEditingTitle = false;
  InkSession _ink = InkSession();

  @override
  void initState() {
    super.initState();
    _workspace = WorkspaceController(
      widget.repository,
      initialDocument: widget.initialDocument,
    )..addListener(_onWorkspaceChanged);
    _textController = TextEditingController(text: _workspace.document.content);
    _titleController = TextEditingController(text: _workspace.document.name);
    _editorScrollController = ScrollController();
    _titleFocusNode = FocusNode()..addListener(_onTitleFocusChanged);
    _undoController = UndoHistoryController();
    _loadBundledExample();
  }

  Future<void> _loadBundledExample() async {
    try {
      final content = await rootBundle.loadString('assets/examples/welcome.md');
      if (!mounted) return;
      _workspace.loadExample(content);
    } catch (_) {
      // The editor remains usable as an empty document if the asset is missing.
    }
  }

  @override
  void dispose() {
    _ink.dispose();
    _workspace
      ..removeListener(_onWorkspaceChanged)
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
    final opened = await _runFileAction(
      _workspace.openDocument,
      successMessage: 'เปิดเอกสารแล้ว',
    );
    if (opened) {
      _resetInk();
      _resetUndoHistory();
    }
  }

  Future<void> _newDocument() async {
    if (!await _confirmDiscardChanges()) return;
    _workspace.newDocument();
    _resetInk();
    _resetUndoHistory();
  }

  Future<void> _saveDocument({bool saveAs = false}) async {
    await _runFileAction(
      saveAs ? _workspace.saveAs : _workspace.save,
      successMessage: _ink.isDirty
          ? 'บันทึก Markdown แล้ว · หมึกยังไม่บันทึก ใช้ปุ่มบันทึกในโหมดจด'
          : 'บันทึกเอกสารแล้ว',
    );
  }

  void _resetInk() {
    final previous = _ink;
    setState(() => _ink = InkSession());
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
      picked = await widget.mermaidFileSource.pick();
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
          Navigator.of(context).pop(
            _workspace.document.isDirty ? null : _workspace.document,
          );
        }
      },
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_workspace.isBusy) const LinearProgressIndicator(minHeight: 2),
            _buildWorkspaceHeader(document),
            if (_workspace.mode == WorkspaceMode.edit)
              _buildFormattingToolbar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Card(
                  key: const Key('document-surface'),
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: _workspace.mode == WorkspaceMode.edit
                            ? _buildEditor()
                            : _workspace.mode == WorkspaceMode.ink
                            ? InkPage(
                                key: ObjectKey(_ink),
                                session: _ink,
                                markdown: document.content,
                                name: document.name,
                                imageDirectory: _imageDirectory,
                              )
                            : _buildPreview(),
                      ),
                      if (_workspace.mode != WorkspaceMode.ink)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${document.content.split('\n').length} บรรทัด · ${document.content.characters.length} ตัวอักษร',
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
  );
}

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
                      const SizedBox(width: 340),
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
      segments: [
        ButtonSegment(
          value: WorkspaceMode.edit,
          icon: const Icon(Icons.edit_outlined),
          label: compact ? null : const Text('แก้ไข'),
          tooltip: 'แก้ไข Markdown',
        ),
        ButtonSegment(
          value: WorkspaceMode.preview,
          icon: const Icon(Icons.visibility_outlined),
          label: compact ? null : const Text('แสดงผล'),
          tooltip: 'แสดงผล Markdown',
        ),
        ButtonSegment(
          value: WorkspaceMode.ink,
          icon: const Icon(Icons.draw_outlined),
          label: compact ? null : const Text('จด'),
          tooltip: 'จดด้วยปากกา',
        ),
      ],
      selected: {_workspace.mode},
      onSelectionChanged: (selection) => _workspace.setMode(selection.first),
    );
  }

  Widget _buildDocumentActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _workspace.isBusy ? null : _openDocument,
          tooltip: 'เปิดไฟล์',
          icon: const Icon(Icons.folder_open_rounded),
        ),
        IconButton.filledTonal(
          onPressed: _workspace.isBusy ? null : _saveDocument,
          tooltip: 'บันทึก',
          icon: const Icon(Icons.save_rounded),
        ),
        PopupMenuButton<_DocumentAction>(
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
        onList: () => _formatSelectedLines(
          prefixBuilder: (_) => '- ',
          placeholder: 'รายการ',
          removePattern: '- ',
        ),
        onOrderedList: _formatOrderedList,
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
          final gutterWidth = 28.0 + lineCount.toString().length * 8.0;
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
      final editorPainter = _textPainter(
        lines[index].isEmpty ? ' ' : lines[index],
        editorStyle,
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
    if (!scrollController.hasClients) return 0;
    return scrollController.offset;
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