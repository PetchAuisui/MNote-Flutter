import 'package:flutter/foundation.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';

enum WorkspaceMode { edit, split, preview, ink }

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this._repository, {MarkdownDocument? initialDocument})
    : _document = initialDocument ?? MarkdownDocument.untitled();

  final DocumentRepository _repository;
  MarkdownDocument _document;
  WorkspaceMode _mode = WorkspaceMode.split;
  bool _isBusy = false;
  String? _errorMessage;

  MarkdownDocument get document => _document;
  WorkspaceMode get mode => _mode;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  void updateContent(String content) {
    if (content == _document.content) return;
    _document = _document.edit(content);
    notifyListeners();
  }

  void updateName(String name) {
    if (name == _document.name) return;
    _document = _document.rename(name);
    notifyListeners();
  }

  void setMode(WorkspaceMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  void newDocument() {
    _document = MarkdownDocument.untitled();
    _mode = WorkspaceMode.split;
    _errorMessage = null;
    notifyListeners();
  }

  bool loadExample(String content) {
    if (_document.name != 'Untitled.md' ||
        _document.content.isNotEmpty ||
        _document.uri != null) {
      return false;
    }
    _document = MarkdownDocument.example(content);
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  bool upgradeExample(String previous, String current) {
    if (_document.name != 'Welcome.md' ||
        _document.uri != null ||
        _document.isDirty ||
        _document.content != previous) {
      return false;
    }
    _document = MarkdownDocument.example(current);
    notifyListeners();
    return true;
  }

  Future<bool> openDocument() {
    return _run(() async {
      final document = await _repository.open();
      if (document == null) return false;
      _document = document;
      return true;
    });
  }

  Future<bool> save() {
    return _run(() async {
      final document = await _repository.save(_document);
      if (document == null) return false;
      _document = document;
      return true;
    });
  }

  Future<bool> saveAs() {
    return _run(() async {
      final document = await _repository.saveAs(_document);
      if (document == null) return false;
      _document = document;
      return true;
    });
  }

  void clearError() {
    _errorMessage = null;
  }

  Future<bool> _run(Future<bool> Function() action) async {
    if (_isBusy) return false;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await action();
    } on DocumentReadException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'ไม่สามารถทำรายการกับไฟล์นี้ได้ กรุณาลองอีกครั้ง';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
