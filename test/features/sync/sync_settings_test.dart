import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/models/note_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

DocumentItem doc(String content, [SyncMode mode = SyncMode.auto]) =>
    DocumentItem(
      id: 'd',
      name: 'a.md',
      content: content,
      updatedAt: DateTime(2026),
      syncMode: mode,
    );

void main() {
  test('defaults: on, ink on, limit at the Firestore cap', () {
    final s = SyncSettings();
    expect(s.enabled, isTrue);
    expect(s.syncInk, isTrue);
    expect(s.maxContentBytes, SyncSettings.hardLimitBytes);
  });

  test('values persist across loads', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SyncSettings();
    s
      ..enabled = false
      ..syncInk = false
      ..maxContentBytes = 100 * 1024;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final loaded = await SyncSettings.load();
    expect(loaded.enabled, isFalse);
    expect(loaded.syncInk, isFalse);
    expect(loaded.maxContentBytes, 100 * 1024);
  });

  test('the limit cannot exceed the Firestore cap', () {
    final s = SyncSettings(maxContentBytes: 10 * 1024 * 1024);
    expect(s.maxContentBytes, SyncSettings.hardLimitBytes);
    s.maxContentBytes = 99 * 1024 * 1024;
    expect(s.maxContentBytes, SyncSettings.hardLimitBytes);
  });

  test('notifies listeners on change', () {
    final s = SyncSettings();
    var calls = 0;
    s.addListener(() => calls++);
    s.enabled = false;
    s.maxContentBytes = 1000;
    expect(calls, 2);
  });

  test('allows() follows enabled, mode and size', () {
    final s = SyncSettings(maxContentBytes: 10);
    expect(s.allows(doc('short')), isTrue);
    expect(s.allows(doc('x' * 20)), isFalse);
    expect(s.allows(doc('x' * 20, SyncMode.always)), isTrue);
    expect(s.allows(doc('short', SyncMode.never)), isFalse);
    s.enabled = false;
    expect(s.allows(doc('short', SyncMode.always)), isFalse);
  });

  test('fits() measures UTF-8 bytes and skips encoding when obvious', () {
    expect(SyncSettings.fits('abc', 3), isTrue);
    expect(SyncSettings.fits('abcd', 3), isFalse);
    // Each Thai letter is 3 bytes in UTF-8 but 1 UTF-16 unit.
    expect(SyncSettings.fits('กขค', 9), isTrue);
    expect(SyncSettings.fits('กขคง', 9), isFalse);
  });
}
