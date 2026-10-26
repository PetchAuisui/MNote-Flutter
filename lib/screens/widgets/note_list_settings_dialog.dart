import 'package:flutter/material.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/core/theme/app_theme.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/presentation/widgets/account_avatar_button.dart';
import 'package:mnote/features/sync/domain/sync_settings.dart';
import 'package:mnote/l10n/l10n.dart';
import 'package:mnote/screens/widgets/about_section.dart';
import 'package:mnote/l10n/language_preferences.dart';
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
              Text(
                context.l10n.settingsTitle,
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
                    context.l10n.accentTitle,
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
                    context.l10n.themeTitle,
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
                          label: _ModeLabel(context.l10n.themeSystem),
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
                          label: _ModeLabel(context.l10n.themeLight),
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
                          label: _ModeLabel(context.l10n.themeDark),
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
                          ? context.l10n.themeHintSystem
                          : (currentMode == ThemeMode.dark
                                ? context.l10n.themeHintDark
                                : context.l10n.themeHintLight),
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
                  const _LanguageSection(),
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
                  const AboutSection(),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.done),
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
      label: context.l10n.accentName(context.l10n.accentLabel(accent)),
      child: Tooltip(
        message: context.l10n.accentLabel(accent),
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
              context.l10n.syncTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              key: const Key('sync-enabled-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.syncFiles),
              subtitle: Text(context.l10n.syncFilesOffHint),
              value: enabled,
              onChanged: (v) => settings.enabled = v,
            ),
            SwitchListTile(
              key: const Key('sync-ink-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.syncInk),
              value: settings.syncInk,
              onChanged: enabled ? (v) => settings.syncInk = v : null,
            ),
            SwitchListTile(
              key: const Key('sync-wifi-only-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.syncWifiOnly),
              subtitle: Text(context.l10n.syncWifiOnlyHint),
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
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.syncFailed)));
    }
  }

  static String describe(AppLocalizations l, DateTime? at, DateTime now) {
    if (at == null) return l.syncNotYet;
    return l.syncLast(l.timeAgo(at, now));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: widget.repository.lastSyncedAt,
      builder: (context, at, _) => ListTile(
        key: const Key('sync-status-tile'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          widget.enabled
              ? describe(context.l10n, at, DateTime.now())
              : context.l10n.syncOff,
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
                label: Text(context.l10n.syncNow),
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
          context.l10n.accountTitle,
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
            (name != null && name.isNotEmpty) ? name : context.l10n.noName,
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
            title: Text(
              context.l10n.signOut,
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
              context.l10n.editorTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.editorOpenIn, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            SegmentedButton<WorkspaceMode>(
              key: const Key('editor-open-mode'),
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: WorkspaceMode.ink,
                  icon: Icon(Icons.draw_rounded, size: 18),
                  label: Text(context.l10n.tabWrite),
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
            Text(context.l10n.editorFont, style: theme.textTheme.bodyMedium),
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
                            child: Text(
                              font == EditorFont.app
                                  ? context.l10n.fontApp
                                  : font.label,
                              maxLines: 1,
                            ),
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
              label: context.l10n.editorFontSize,
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
              label: context.l10n.editorLineHeight,
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
                context.l10n.editorSample,
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
              context.l10n.editorNote,
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
                child: Text(context.l10n.reset),
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

/// Whether a finger can draw. Pen color and width live in each note's
/// toolbar.
class _InkSection extends StatelessWidget {
  const _InkSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = InkSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.inkTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SwitchListTile(
            key: const Key('ink-finger-drawing'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.inkFinger),
            subtitle: Text(context.l10n.inkFingerHint),
            value: settings.fingerDrawing,
            onChanged: (v) => settings.fingerDrawing = v,
          ),
        ],
      ),
    );
  }
}

/// Lets the user pick the app language.
class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: MnoteApp.languageNotifier,
      builder: (context, current, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.languageTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppLanguage>(
            key: const Key('language-selector'),
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AppLanguage.system,
                label: _ModeLabel(l.languageSystem),
              ),
              ButtonSegment(
                value: AppLanguage.thai,
                label: _ModeLabel(l.languageThai),
              ),
              ButtonSegment(
                value: AppLanguage.english,
                label: _ModeLabel(l.languageEnglish),
              ),
            ],
            selected: {current},
            onSelectionChanged: (s) => LanguagePreferences.set(s.first),
          ),
          const SizedBox(height: 8),
          Text(
            l.languageHint,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
