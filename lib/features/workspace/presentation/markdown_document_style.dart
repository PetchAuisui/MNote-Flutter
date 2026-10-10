import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:mnote/core/theme/app_theme.dart';

abstract final class MarkdownDocumentStyle {
  static const bodySize = 17.0;
  static const lineHeight = 1.55;
  static const maxWidth = 960.0;
  static const headingSizes = [28.0, 24.0, 20.0, 18.0, 17.0, 17.0];
  static const textColor = Color(0xFF202124);

  /// Block backgrounds are half transparent, so highlighter ink beneath the
  /// text shows through them. Over the white page they look like [opaque].
  static Color _translucentOnWhite(int opaque) {
    const alpha = 0.5;
    int channel(int shift) =>
        ((((opaque >> shift) & 0xFF) - (1 - alpha) * 255) / alpha).round();
    return Color.fromARGB(
      (alpha * 255).round(),
      channel(16),
      channel(8),
      channel(0),
    );
  }

  static ThemeData theme(BuildContext context) => ThemeData.from(
    colorScheme: AppTheme.colorScheme(Brightness.light),
    textTheme: Theme.of(
      context,
    ).textTheme.apply(bodyColor: textColor, displayColor: textColor),
    useMaterial3: true,
  );

  static MarkdownStyleSheet sheet(ThemeData theme) {
    final body = theme.textTheme.bodyLarge!.copyWith(
      fontSize: bodySize,
      height: lineHeight,
      color: textColor,
    );
    TextStyle heading(int level) => body.copyWith(
      fontSize: headingSizes[level - 1],
      height: 1.35,
      fontWeight: level <= 3 ? FontWeight.w700 : FontWeight.w600,
    );
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      h1: heading(1),
      h2: heading(2),
      h3: heading(3),
      h4: heading(4),
      h5: heading(5),
      h6: heading(6),
      blockSpacing: 16,
      listIndent: 20,
      listBullet: body,
      listBulletPadding: const EdgeInsets.only(right: 4),
      tableBorder: TableBorder.all(color: const Color(0xFFB0B3B8), width: 1.5),
      blockquote: body,
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      blockquoteDecoration: BoxDecoration(
        color: _translucentOnWhite(0xFFE9E8EF),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: const Border(
          left: BorderSide(color: Color(0xFF4D6495), width: 3),
        ),
      ),
      code: body.copyWith(
        fontFamily: 'monospace',
        fontSize: 15,
        backgroundColor: _translucentOnWhite(0xFFF1F1F3),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      codeblockDecoration: BoxDecoration(
        color: _translucentOnWhite(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(8),
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFDDDEE2), width: 1)),
      ),
    );
  }
}
