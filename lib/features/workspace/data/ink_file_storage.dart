import 'dart:io';

/// Persists a document's ink next to the document itself, as
/// `<document>.ink.json`. Only documents backed by a local file have ink on disk.
abstract interface class InkFileStorage {
  Future<String?> read(Uri documentUri);

  Future<void> write(Uri documentUri, String content);
}

class DeviceInkFileStorage implements InkFileStorage {
  const DeviceInkFileStorage();

  File? _sidecar(Uri documentUri) => documentUri.scheme == 'file'
      ? File('${File.fromUri(documentUri).path}.ink.json')
      : null;

  @override
  Future<String?> read(Uri documentUri) async {
    final file = _sidecar(documentUri);
    if (file == null || !await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(Uri documentUri, String content) async {
    await _sidecar(documentUri)?.writeAsString(content, flush: true);
  }
}
