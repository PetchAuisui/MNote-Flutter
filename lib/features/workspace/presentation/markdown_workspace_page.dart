import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:mnote/features/workspace/data/device_image_picker.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownWorkspacePage extends StatefulWidget {
  const MarkdownWorkspacePage({
    super.key,
    required this.repository,
    this.imagePicker = const DeviceImagePicker(),
  });

  final DocumentRepository repository;
  final DeviceImagePicker imagePicker;

  @override
  State<MarkdownWorkspacePage> createState() => _MarkdownWorkspacePageState();
}

class _MarkdownWorkspacePageState extends State<MarkdownWorkspacePage> {
  late final WorkspaceController _workspace;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _workspace = WorkspaceController(widget.repository)
      ..addListener(_onWorkspaceChanged);
    _textController = TextEditingController(text: _workspace.document.content);
  }

  @override
  void dispose() {
    _workspace
      ..removeListener(_onWorkspaceChanged)
      ..dispose();
    _textController.dispose();
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
    if (mounted) setState(() {});
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_workspace.document.isDirty) return true;
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
    await _runFileAction(
      _workspace.openDocument,
      successMessage: 'เปิดเอกสารแล้ว',
    );
  }

  Future<void> _newDocument() async {
    if (!await _confirmDiscardChanges()) return;
    _workspace.newDocument();
  }

  Future<void> _saveDocument({bool saveAs = false}) async {
    await _runFileAction(
      saveAs ? _workspace.saveAs : _workspace.save,
      successMessage: 'บันทึกเอกสารแล้ว',
    );
  }

  Future<void> _runFileAction(
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    final succeeded = await action();
    if (!mounted) return;
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(_statusLabel, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _workspace.isBusy ? null : _openDocument,
            tooltip: 'เปิดไฟล์',
            icon: const Icon(Icons.folder_open_rounded),
          ),
          IconButton(
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
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_workspace.isBusy) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<WorkspaceMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: WorkspaceMode.edit,
                    icon: Icon(Icons.edit_outlined),
                    label: Text('แก้ไข'),
                  ),
                  ButtonSegment(
                    value: WorkspaceMode.preview,
                    icon: Icon(Icons.visibility_outlined),
                    label: Text('แสดงผล'),
                  ),
                ],
                selected: {_workspace.mode},
                onSelectionChanged: (selection) {
                  _workspace.setMode(selection.first);
                },
              ),
            ),
            if (_workspace.mode == WorkspaceMode.edit)
              _buildFormattingToolbar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: _workspace.mode == WorkspaceMode.edit
                      ? _buildEditor()
                      : _buildPreview(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _statusLabel {
    if (_workspace.isBusy) return 'กำลังดำเนินการ…';
    if (_workspace.document.isDirty) return 'ยังไม่ได้บันทึก';
    if (_workspace.document.uri == null) return 'เอกสารใหม่';
    return 'บันทึกแล้ว';
  }

  Widget _buildFormattingToolbar() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _formatButton(
            icon: Icons.title_rounded,
            tooltip: 'หัวข้อ',
            onPressed: () => _replaceSelection('# ', '', placeholder: 'หัวข้อ'),
          ),
          _formatButton(
            icon: Icons.format_bold_rounded,
            tooltip: 'ตัวหนา',
            onPressed: () =>
                _replaceSelection('**', '**', placeholder: 'ข้อความ'),
          ),
          _formatButton(
            icon: Icons.format_italic_rounded,
            tooltip: 'ตัวเอียง',
            onPressed: () =>
                _replaceSelection('_', '_', placeholder: 'ข้อความ'),
          ),
          _formatButton(
            icon: Icons.format_list_bulleted_rounded,
            tooltip: 'รายการ',
            onPressed: () => _replaceSelection('- ', '', placeholder: 'รายการ'),
          ),
          _formatButton(
            icon: Icons.format_quote_rounded,
            tooltip: 'ข้อความอ้างอิง',
            onPressed: () =>
                _replaceSelection('> ', '', placeholder: 'ข้อความ'),
          ),
          _formatButton(
            icon: Icons.code_rounded,
            tooltip: 'โค้ด',
            onPressed: () =>
                _replaceSelection('\n```\n', '\n```\n', placeholder: 'code'),
          ),
          _formatButton(
            icon: Icons.link_rounded,
            tooltip: 'ลิงก์',
            onPressed: () =>
                _replaceSelection('[', '](https://)', placeholder: 'ชื่อลิงก์'),
          ),
          _formatButton(
            icon: Icons.image_outlined,
            tooltip: 'แทรกรูป',
            onPressed: _insertImage,
          ),
        ],
      ),
    );
  }

  Widget _formatButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IconButton.outlined(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        key: const Key('markdown-editor'),
        controller: _textController,
        expands: true,
        minLines: null,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(fontFamily: 'monospace', height: 1.55),
        decoration: const InputDecoration(
          hintText: 'Read Markdown. Write freely.',
          contentPadding: EdgeInsets.all(16),
        ),
        onChanged: _workspace.updateContent,
      ),
    );
  }

  Widget _buildPreview() {
    final content = _workspace.document.content;
    if (content.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'ยังไม่มีเนื้อหา\nกลับไปที่โหมดแก้ไขเพื่อเริ่มเขียน',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Markdown(
      key: const Key('markdown-preview'),
      data: content,
      selectable: true,
      imageDirectory: _imageDirectory,
      padding: const EdgeInsets.all(24),
      onTapLink: (text, href, title) => _openLink(href),
    );
  }

  String? get _imageDirectory {
    final uri = _workspace.document.uri;
    if (uri == null || uri.scheme != 'file') return null;
    return uri.resolve('.').toString();
  }
}

enum _DocumentAction { newDocument, saveAs }
