import 'dart:io';

/// Persists a document's ink next to the document itself, as
/// `<document>.ink.json`. Only documents backed by a local file have ink on disk.
abstract interface class InkFileStorage {
  Future<String?> read(Uri documentUri);

  Future<void> write(Uri documentUri, String content);

  /// Keeps an existing ink file that could not be read, so new ink written
  /// next to the document cannot destroy it.
  Future<void> backup(Uri documentUri);
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
    final file = _sidecar(documentUri);
    if (file == null) return;
    // Write beside the target and rename over it, so a crash mid-write leaves
    // the previous ink intact instead of a truncated file.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(content, flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> backup(Uri documentUri) async {
    final file = _sidecar(documentUri);
    if (file == null || !await file.exists()) return;
    await file.copy('${file.path}.bak');
  }
}
