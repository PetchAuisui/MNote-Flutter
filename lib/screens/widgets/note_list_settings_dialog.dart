import 'package:flutter/material.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';

class NoteListSettingsDialog extends StatelessWidget {
  const NoteListSettingsDialog({super.key, this.syncSettings});

  /// When provided, a cloud sync section is shown.
  final SyncSettings? syncSettings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: MnoteApp.themeModeNotifier,
      builder: (context, currentMode, _) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'การตั้งค่า',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สีของแอป (Accent)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<AppAccent>(
                    valueListenable: MnoteApp.accentNotifier,
                    builder: (context, currentAccent, _) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final accent in AppAccent.values)
                            _AccentSwatch(
                              accent: accent,
                              selected: accent == currentAccent,
                              onTap: () =>
                                  MnoteApp.accentNotifier.value = accent,
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'โหมดการแสดงผล (Theme)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(
                            Icons.brightness_auto_rounded,
                            color: Colors.teal,
                            size: 18,
                          ),
                          label: _ModeLabel('ตามเครื่อง'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(
                            Icons.wb_sunny_rounded,
                            color: Colors.orange,
                            size: 18,
                          ),
                          label: _ModeLabel('สว่าง'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(
                            Icons.dark_mode_rounded,
                            color: Colors.indigoAccent,
                            size: 18,
                          ),
                          label: _ModeLabel('มืด'),
                        ),
                      ],
                      selected: {currentMode},
                      onSelectionChanged: (newSelection) {
                        MnoteApp.setThemeMode(newSelection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      currentMode == ThemeMode.system
                          ? 'ค่าเริ่มต้น: ปรับมืด/สว่างอัตโนมัติตามโหมดของเครื่อง'
                          : (currentMode == ThemeMode.dark
                                ? 'เปิดใช้งานโหมดมืด'
                                : 'เปิดใช้งานโหมดสว่าง'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (syncSettings != null) ...[
                    const SizedBox(height: 20),
                    _SyncSection(settings: syncSettings!),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'MNote v1.0.0 • Local-First Markdown Workspace',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('เสร็จสิ้น'),
            ),
          ],
        );
      },
    );
  }
}

/// A single selectable color dot in the accent picker.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'สี${accent.label}',
      child: Tooltip(
        message: accent.label,
        child: InkResponse(
          key: ValueKey('accent_${accent.name}'),
          onTap: onTap,
          radius: 28,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.swatch,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? colorScheme.onSurface : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    color:
                        ThemeData.estimateBrightnessForColor(accent.swatch) ==
                            Brightness.light
                        ? const Color(0xDD000000)
                        : Colors.white,
                    size: 22,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Keeps a mode name on one line, shrinking it on narrow dialogs.
class _ModeLabel extends StatelessWidget {
  const _ModeLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

String _limitLabel(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${bytes ~/ 1024} KB';

/// Switches and the size limit for syncing notes to the account.
class _SyncSection extends StatelessWidget {
  const _SyncSection({required this.settings});

  final SyncSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final enabled = settings.enabled;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ซิงก์กับบัญชี (Cloud sync)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              key: const Key('sync-enabled-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('ซิงก์ไฟล์ขึ้นบัญชี'),
              subtitle: const Text('ปิดแล้วไฟล์จะอยู่ในเครื่องนี้เท่านั้น'),
              value: enabled,
              onChanged: (v) => settings.enabled = v,
            ),
            SwitchListTile(
              key: const Key('sync-ink-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('ซิงก์หมึกปากกา'),
              value: settings.syncInk,
              onChanged: enabled ? (v) => settings.syncInk = v : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: enabled,
              title: const Text('ขนาดไฟล์สูงสุดที่ซิงก์'),
              subtitle: const Text('ไฟล์ที่ใหญ่กว่านี้จะไม่ถูกอัปโหลด'),
              trailing: DropdownButton<int>(
                key: const Key('sync-limit-dropdown'),
                value:
                    SyncSettings.limitChoices.contains(settings.maxContentBytes)
                    ? settings.maxContentBytes
                    : SyncSettings.hardLimitBytes,
                onChanged: enabled
                    ? (v) {
                        if (v != null) settings.maxContentBytes = v;
                      }
                    : null,
                items: [
                  for (final bytes in SyncSettings.limitChoices)
                    DropdownMenuItem(
                      value: bytes,
                      child: Text(_limitLabel(bytes)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
