import 'package:flutter/material.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/presentation/widgets/account_avatar_button.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/features/sync/domain/syncable_document_repository.dart';
import 'package:mnote/features/workspace/presentation/editor_settings.dart';
import 'package:mnote/features/workspace/presentation/ink_settings.dart';
import 'package:mnote/features/workspace/presentation/markdown_document_style.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';

class NoteListSettingsDialog extends StatelessWidget {
  const NoteListSettingsDialog({
    super.key,
    this.syncSettings,
    this.syncRepository,
    this.authRepository,
    this.onSignOut,
    this.onDeleteAccount,
  });

  /// When provided with a signed-in user, an account section is shown.
  final AuthRepository? authRepository;
  final Future<void> Function()? onSignOut;

  /// Deletes the account; receives the password for email accounts.
  final Future<void> Function(String password)? onDeleteAccount;

  /// When provided, a cloud sync section is shown.
  final SyncSettings? syncSettings;

  /// When provided, the sync section shows the last sync and a sync-now button.
  final SyncableDocumentRepository? syncRepository;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: MnoteApp.themeModeNotifier,
      builder: (context, currentMode, _) {
        final theme = Theme.of(context);
        // Narrow phones have no room for icons next to the mode names.
        final compact = MediaQuery.sizeOf(context).width < 420;
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
                  if (authRepository?.currentUser != null) ...[
                    _AccountSection(
                      authRepository: authRepository!,
                      onSignOut: onSignOut,
                      onDeleteAccount: onDeleteAccount,
                    ),
                    const SizedBox(height: 24),
                  ],
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
                      // One row: each circle gets an equal slot (with a small
                      // gap) and is drawn up to 44 wide, so it shrinks evenly
                      // on narrow dialogs without touching its neighbours.
                      return Row(
                        children: [
                          for (final accent in AppAccent.values)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 44,
                                      maxHeight: 44,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: _AccentSwatch(
                                        accent: accent,
                                        selected: accent == currentAccent,
                                        onTap: () =>
                                            MnoteApp.accentNotifier.value =
                                                accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: compact
                              ? null
                              : const Icon(
                                  Icons.brightness_auto_rounded,
                                  color: Colors.teal,
                                  size: 18,
                                ),
                          label: const _ModeLabel('ตามเครื่อง'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: compact
                              ? null
                              : const Icon(
                                  Icons.wb_sunny_rounded,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                          label: const _ModeLabel('สว่าง'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: compact
                              ? null
                              : const Icon(
                                  Icons.dark_mode_rounded,
                                  color: Colors.indigoAccent,
                                  size: 18,
                                ),
                          label: const _ModeLabel('มืด'),
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
                  const SizedBox(height: 20),
                  const _EditorSection(),
                  const SizedBox(height: 20),
                  const _InkSection(),
                  if (syncSettings != null) ...[
                    const SizedBox(height: 20),
                    _SyncSection(
                      settings: syncSettings!,
                      repository: syncRepository,
                    ),
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

/// A mode name on one line. All three labels share one size (large system
/// fonts are capped) so they look the same; FittedBox is only a safety net.
class _ModeLabel extends StatelessWidget {
  const _ModeLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(fontSize: 13),
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
      ),
    );
  }
}

/// Switches for syncing notes to the account, plus the sync status.
class _SyncSection extends StatelessWidget {
  const _SyncSection({required this.settings, this.repository});

  final SyncSettings settings;
  final SyncableDocumentRepository? repository;

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
              subtitle: const Text('ปิดแล้วเก็บในเครื่องนี้เท่านั้น'),
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
            SwitchListTile(
              key: const Key('sync-wifi-only-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('ซิงก์เฉพาะ Wi-Fi'),
              subtitle: const Text('ไม่ใช้เน็ตมือถือในการซิงก์'),
              value: settings.wifiOnly,
              onChanged: enabled ? (v) => settings.wifiOnly = v : null,
            ),
            if (repository != null)
              _SyncStatusTile(repository: repository!, enabled: enabled),
          ],
        );
      },
    );
  }
}

/// When the library was last confirmed in the cloud, with a sync-now button.
class _SyncStatusTile extends StatefulWidget {
  const _SyncStatusTile({required this.repository, required this.enabled});

  final SyncableDocumentRepository repository;
  final bool enabled;

  @override
  State<_SyncStatusTile> createState() => _SyncStatusTileState();
}

class _SyncStatusTileState extends State<_SyncStatusTile> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final ok = await widget.repository.syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('ซิงก์ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่'),
        ),
      );
    }
  }

  static String describe(DateTime? at, DateTime now) {
    if (at == null) return 'ยังไม่ได้ซิงก์ในรอบนี้';
    final diff = now.difference(at);
    final String ago;
    if (diff.inSeconds < 60) {
      ago = 'เมื่อสักครู่';
    } else if (diff.inMinutes < 60) {
      ago = '${diff.inMinutes} นาทีที่แล้ว';
    } else if (diff.inHours < 24) {
      ago = '${diff.inHours} ชั่วโมงที่แล้ว';
    } else {
      ago = '${diff.inDays} วันที่แล้ว';
    }
    return 'ซิงก์ล่าสุด: $ago';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: widget.repository.lastSyncedAt,
      builder: (context, at, _) => ListTile(
        key: const Key('sync-status-tile'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          widget.enabled ? describe(at, DateTime.now()) : 'ปิดการซิงก์อยู่',
          style: const TextStyle(fontSize: 14),
        ),
        trailing: _syncing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : TextButton.icon(
                key: const Key('sync-now-button'),
                onPressed: widget.enabled ? _syncNow : null,
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('ซิงก์ตอนนี้'),
              ),
      ),
    );
  }
}

/// Who is signed in, with sign-out and delete-account actions.
class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.authRepository,
    this.onSignOut,
    this.onDeleteAccount,
  });

  final AuthRepository authRepository;
  final Future<void> Function()? onSignOut;
  final Future<void> Function(String password)? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = authRepository.currentUser!;
    final name = user.displayName?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'บัญชี (Account)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        ListTile(
          key: const Key('settings-account-tile'),
          contentPadding: EdgeInsets.zero,
          leading: AccountAvatar(user: user, radius: 22),
          title: Text(
            (name != null && name.isNotEmpty) ? name : 'ไม่ระบุชื่อ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => AccountDialog(
              user: user,
              authRepository: authRepository,
              onDeleteAccount: onDeleteAccount == null
                  ? null
                  : (password) async {
                      Navigator.of(context).pop();
                      await onDeleteAccount!(password);
                    },
            ),
          ),
        ),
        if (onSignOut != null)
          ListTile(
            key: const Key('settings-sign-out'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFD9534F)),
            title: const Text(
              'ออกจากระบบ',
              style: TextStyle(color: Color(0xFFD9534F)),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              await onSignOut!();
            },
          ),
      ],
    );
  }
}

/// How the typing view looks and which mode new notes open in.
class _EditorSection extends StatelessWidget {
  const _EditorSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = EditorSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ตัวแก้ไข (Editor)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text('เปิดโน้ตด้วยโหมด', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            SegmentedButton<WorkspaceMode>(
              key: const Key('editor-open-mode'),
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: WorkspaceMode.ink,
                  icon: Icon(Icons.draw_rounded, size: 18),
                  label: Text('เขียน'),
                ),
                ButtonSegment(
                  value: WorkspaceMode.split,
                  icon: Icon(Icons.keyboard_rounded, size: 18),
                  label: Text('Markdown'),
                ),
              ],
              selected: {settings.openMode},
              onSelectionChanged: (s) => settings.openMode = s.first,
            ),
            const SizedBox(height: 16),
            Text('ฟอนต์ของข้อความ', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final font in EditorFont.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        key: ValueKey('editor-font-${font.name}'),
                        showCheckmark: false,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        label: SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(font.label, maxLines: 1),
                          ),
                        ),
                        selected: settings.font == font,
                        onSelected: (_) => settings.font = font,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _LabeledSlider(
              sliderKey: const Key('editor-font-size'),
              label: 'ขนาดตัวอักษร',
              valueLabel: settings.fontSize.round().toString(),
              value: settings.fontSize,
              min: EditorSettings.minFontSize,
              max: EditorSettings.maxFontSize,
              divisions:
                  (EditorSettings.maxFontSize - EditorSettings.minFontSize)
                      .round(),
              onChanged: (v) => settings.fontSize = v,
            ),
            _LabeledSlider(
              sliderKey: const Key('editor-line-height'),
              label: 'ระยะบรรทัด',
              valueLabel: settings.lineHeight.toStringAsFixed(2),
              value: settings.lineHeight,
              min: EditorSettings.minLineHeight,
              max: EditorSettings.maxLineHeight,
              divisions: 14,
              onChanged: (v) => settings.lineHeight = v,
            ),
            Container(
              key: const Key('editor-preview'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                'ตัวอย่างข้อความ The quick brown fox',
                style: settings.textOptions.apply(
                  TextStyle(
                    fontSize: settings.fontSize,
                    height: settings.lineHeight,
                    color: MarkdownDocumentStyle.textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'มีผลกับแท็บเขียนและ Markdown โน้ตที่วาดหมึกไว้แล้วจะคงขนาดเดิม เพื่อให้หมึกตรงกับตัวอักษรเสมอ',
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('editor-reset'),
                onPressed: settings.isDefaultLook ? null : settings.resetLook,
                child: const Text('คืนค่าเริ่มต้น'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.sliderKey,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            key: sliderKey,
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 32, child: Text(valueLabel, textAlign: TextAlign.end)),
      ],
    );
  }
}

/// How the pen starts in a new note, and whether a finger can draw.
class _InkSection extends StatelessWidget {
  const _InkSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = InkSettings.instance;
    final labelStyle = theme.textTheme.bodyMedium;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ปากกา (Ink)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text('สีปากกา', style: labelStyle),
            const SizedBox(height: 8),
            _SwatchRow(
              keyPrefix: 'ink-pen-color',
              colors: InkSettings.penColors,
              selected: settings.penColor,
              onSelected: (c) => settings.penColor = c,
            ),
            const SizedBox(height: 16),
            Text('ความหนาเส้น', style: labelStyle),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final width in InkSettings.penWidths)
                  Expanded(
                    child: Center(
                      child: InkResponse(
                        key: ValueKey('ink-pen-width-${width.round()}'),
                        radius: 28,
                        onTap: () => settings.penWidth = width,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: settings.penWidth == width
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: settings.penWidth == width ? 2.5 : 1,
                            ),
                          ),
                          child: Container(
                            width: 6 + width,
                            height: 6 + width,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: settings.penColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('สีไฮไลต์', style: labelStyle),
            const SizedBox(height: 8),
            _SwatchRow(
              keyPrefix: 'ink-highlight-color',
              colors: InkSettings.highlightColors,
              selected: settings.highlightColor,
              onSelected: (c) => settings.highlightColor = c,
            ),
            SwitchListTile(
              key: const Key('ink-finger-drawing'),
              contentPadding: EdgeInsets.zero,
              title: const Text('วาดด้วยนิ้วได้'),
              subtitle: const Text(
                'ปิดไว้: วาดได้เฉพาะปากกา/Apple Pencil นิ้วใช้เลื่อนหน้า',
              ),
              value: settings.fingerDrawing,
              onChanged: (v) => settings.fingerDrawing = v,
            ),
            Text(
              'ใช้ตอนเปิดโน้ต เปลี่ยนในแถบเครื่องมือของโน้ตได้ตามต้องการ',
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('ink-reset'),
                onPressed: settings.isDefault ? null : settings.reset,
                child: const Text('คืนค่าเริ่มต้น'),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A row of color dots; the selected one gets a ring and a check.
class _SwatchRow extends StatelessWidget {
  const _SwatchRow({
    required this.keyPrefix,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final String keyPrefix;
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final color in colors)
          Expanded(
            child: Center(
              child: InkResponse(
                key: ValueKey(
                  '$keyPrefix-${color.toARGB32().toRadixString(16)}',
                ),
                radius: 28,
                onTap: () => onSelected(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == selected
                          ? scheme.onSurface
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: color == selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color:
                              ThemeData.estimateBrightnessForColor(color) ==
                                  Brightness.light
                              ? const Color(0xDD000000)
                              : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
