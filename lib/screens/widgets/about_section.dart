import 'package:flutter/material.dart';
import 'package:mnote/l10n/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a web link outside the app. Replaced in tests.
Future<bool> Function(Uri url) aboutLinkOpener = (url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// The app's home on GitHub.
final aboutRepositoryUrl = Uri.parse(
  'https://github.com/PetchAuisui/MNote-Flutter',
);

/// Where problems and feedback are reported.
final aboutIssuesUrl = Uri.parse(
  'https://github.com/PetchAuisui/MNote-Flutter/issues',
);

/// App name and version, open-source licenses and links to report problems.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  /// `1.0.0 (1)`, or just the version when there is no build number.
  static String describeVersion(PackageInfo info) => info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';

  Future<void> _open(BuildContext context, Uri url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.aboutOpenFailed;
    bool ok;
    try {
      ok = await aboutLinkOpener(url);
    } catch (_) {
      ok = false;
    }
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.aboutTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo.png',
                width: 40,
                height: 40,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.edit_note, size: 40),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mnote',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      return Text(
                        info == null
                            ? 'Local-First Markdown Workspace'
                            : '${l.aboutVersion(describeVersion(info))} • '
                                  'Local-First Markdown Workspace',
                        key: const Key('about-version'),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ListTile(
          key: const Key('about-feedback'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.feedback_outlined),
          title: Text(l.aboutFeedback),
          subtitle: Text(l.aboutFeedbackHint),
          onTap: () => _open(context, aboutIssuesUrl),
        ),
        ListTile(
          key: const Key('about-source'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.code_rounded),
          title: Text(l.aboutSource),
          onTap: () => _open(context, aboutRepositoryUrl),
        ),
        ListTile(
          key: const Key('about-licenses'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(l.aboutLicenses),
          onTap: () async {
            final info = await PackageInfo.fromPlatform();
            if (!context.mounted) return;
            showLicensePage(
              context: context,
              applicationName: 'Mnote',
              applicationVersion: describeVersion(info),
            );
          },
        ),
      ],
    );
  }
}
