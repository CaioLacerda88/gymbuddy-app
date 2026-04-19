import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Primary button for GymBuddy.
///
/// Renders an [ElevatedButton] on top of a gradient background.
/// Supports an optional [icon], a loading spinner that preserves the
/// semantic [label] for accessibility (BUG-002), and a custom [gradient].
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradient = AppTheme.primaryGradient,
    this.semanticsIdentifier,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final LinearGradient gradient;

  /// Optional Semantics identifier for locale-independent E2E selectors.
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = isLoading || onPressed == null;

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.onPrimary,
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), const SizedBox(width: 8), Text(label)],
      );
    } else {
      child = Text(label);
    }

    return Semantics(
      container: true,
      identifier: semanticsIdentifier,
      label: label,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: disabled ? null : gradient,
          color: disabled
              ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
