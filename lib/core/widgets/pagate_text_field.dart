import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

/// Standard text input field for Págate-IA.
///
/// Wraps [TextFormField] with consistent pill-shaped styling, optional
/// prefix icon, suffix actions, and password visibility toggle built-in.
class PagateTextField extends StatefulWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool readOnly;
  final IconData? prefixIcon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool autofocus;

  const PagateTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.readOnly = false,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onTap,
    this.inputFormatters,
    this.maxLength,
    this.autofocus = false,
  });

  @override
  State<PagateTextField> createState() => _PagateTextFieldState();
}

class _PagateTextFieldState extends State<PagateTextField> {
  bool _isObscured = true;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword && _isObscured,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        labelText: widget.labelText,
        counterText: '',
        prefixIcon: widget.prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.sm,
                ),
                child: Icon(
                  widget.prefixIcon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: AppIconSize.sm,
                ),
              )
            : null,
        prefixIconConstraints: widget.prefixIcon != null
            ? const BoxConstraints(minWidth: AppSizes.backButtonSize)
            : null,
        suffixIcon: _buildSuffix(),
      ),
    );
  }

  Widget? _buildSuffix() {
    if (widget.isPassword) {
      return IconButton(
        icon: Icon(
          _isObscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: AppColors.textTertiary,
          size: AppIconSize.sm,
        ),
        onPressed: () {
          setState(() {
            _isObscured = !_isObscured;
          });
        },
      );
    }
    return widget.suffix;
  }
}
