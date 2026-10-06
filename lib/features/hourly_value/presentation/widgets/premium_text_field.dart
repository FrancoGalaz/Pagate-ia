import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text.dart';

/// Premium text input field with label and validation (Dark theme).
class PremiumTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final String? prefix;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool enabled;

  const PremiumTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixIcon,
    this.prefix,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
  });

  @override
  Widget build(final BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.weight(
              Theme.of(context).textTheme.titleMedium!,
              600,
            ).copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            enabled: enabled,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: suffixIcon,
              prefixText: prefix,
              counterText: '', // Hide character counter
            ),
          ),
        ],
      );
}
