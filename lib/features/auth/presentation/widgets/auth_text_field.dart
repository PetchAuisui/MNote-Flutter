import 'package:flutter/material.dart';
import 'package:mnote/core/theme/brand_palette.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  OutlineInputBorder _border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BrandPalette.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF5A6C80);
    final fillColor = isDark
        ? theme.colorScheme.surfaceContainerLow
        : Colors.white;

    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, color: iconColor),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                icon: Icon(
                  _hidden ? Icons.visibility_off : Icons.visibility,
                  color: iconColor,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        filled: true,
        fillColor: fillColor,
        enabledBorder: _border(palette.border),
        focusedBorder: _border(palette.primary, 1.8),
        errorBorder: _border(const Color(0xFFD9534F)),
        focusedErrorBorder: _border(const Color(0xFFD9534F), 1.8),
      ),
    );
  }
}
