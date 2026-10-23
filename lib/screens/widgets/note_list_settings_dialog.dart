import 'package:flutter/material.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/presentation/widgets/account_avatar_button.dart';
import 'package:mnote/features/auth/presentation/widgets/delete_account_dialog.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';

class NoteListSettingsDialog extends StatelessWidget {
  const NoteListSettingsDialog({
    super.key,
    this.syncSettings,
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

/// Switches for syncing notes to the account.
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
          ],
        );
      },
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
              onSignOut: () async {
                Navigator.of(context).pop();
                await onSignOut?.call();
              },
            ),
          ),
        ),
        if (onSignOut != null)
          ListTile(
            key: const Key('settings-sign-out'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded),
            title: const Text('ออกจากระบบ'),
            onTap: () async {
              Navigator.of(context).pop();
              await onSignOut!();
            },
          ),
        if (onDeleteAccount != null)
          ListTile(
            key: const Key('settings-delete-account'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_forever_rounded,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'ลบบัญชี',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('ลบบัญชีและไฟล์บน cloud ถาวร'),
            onTap: () async {
              final password = await showDialog<String>(
                context: context,
                builder: (_) => DeleteAccountDialog(user: user),
              );
              if (password == null || !context.mounted) return;
              Navigator.of(context).pop();
              await onDeleteAccount!(password);
            },
          ),
      ],
    );
  }
}
