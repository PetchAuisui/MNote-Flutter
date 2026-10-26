import 'package:mnote/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:mnote/models/note_item.dart';

/// Colors a folder can take, as ARGB values.
const folderColorChoices = <int>[
  0xFFE53935,
  0xFFFB8C00,
  0xFFFDD835,
  0xFF43A047,
  0xFF00ACC1,
  0xFF1E88E5,
  0xFF8E24AA,
  0xFFD81B60,
  0xFF6D4C41,
  0xFF757575,
];

/// The folder's own color, or [fallback] when none was chosen.
Color folderColor(FolderItem folder, Color fallback) =>
    folder.colorValue == null ? fallback : Color(folder.colorValue!);

/// The outcome of [showFolderColorDialog]; `color` is null for the default.
typedef FolderColorChoice = ({int? color});

/// Asks which color [folder] should have. Returns null when dismissed.
Future<FolderColorChoice?> showFolderColorDialog(
  BuildContext context,
  FolderItem folder,
) {
  return showDialog<FolderColorChoice>(
    context: context,
    builder: (ctx) {
      final primary = Theme.of(ctx).colorScheme.primary;
      return AlertDialog(
        title: Text(context.l10n.folderColorTitle),
        content: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _Swatch(
              key: const Key('folder-color-default'),
              color: primary,
              selected: folder.colorValue == null,
              label: context.l10n.defaultColor,
              onTap: () => Navigator.pop(ctx, (color: null)),
            ),
            for (final value in folderColorChoices)
              _Swatch(
                key: Key('folder-color-${value.toRadixString(16)}'),
                color: Color(value),
                selected: folder.colorValue == value,
                onTap: () => Navigator.pop(ctx, (color: value)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
        ],
      );
    },
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    this.label,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label ?? context.l10n.folderColorLabel,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        ),
      ),
    );
  }
}
