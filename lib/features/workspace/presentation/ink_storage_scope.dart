import 'package:flutter/widgets.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';

/// Supplies the ink storage (e.g. one that syncs to the cloud) to ink pages.
class InkStorageScope extends InheritedWidget {
  const InkStorageScope({
    super.key,
    required this.storage,
    required super.child,
  });

  final InkFileStorage storage;

  static InkFileStorage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InkStorageScope>()?.storage;

  @override
  bool updateShouldNotify(InkStorageScope oldWidget) =>
      storage != oldWidget.storage;
}
