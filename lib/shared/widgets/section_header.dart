import 'package:flutter/material.dart';

/// A reusable section header label used across the app.
///
/// Displays uppercase text in `labelLarge` style with reduced opacity
/// that comfortably passes WCAG AA contrast on the dark theme.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.semanticsIdentifier,
    super.key,
  });

  final String title;

  /// Optional Semantics identifier for locale-independent E2E selectors.
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
      ),
    );
    if (semanticsIdentifier != null) {
      return Semantics(
        container: true,
        identifier: semanticsIdentifier,
        child: text,
      );
    }
    return text;
  }
}
