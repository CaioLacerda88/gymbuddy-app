import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.gradient = AppTheme.primaryGradient,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;

    return Container(
      decoration: BoxDecoration(
        gradient: disabled ? null : gradient,
        color: disabled ? Colors.grey.shade800 : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
