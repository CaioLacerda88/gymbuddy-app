import 'package:flutter/material.dart';

/// Renders an "ABOUT" section header with the exercise description text.
///
/// Collapses to nothing when [description] is null or empty.
class ExerciseDescriptionSection extends StatelessWidget {
  const ExerciseDescriptionSection({super.key, required this.description});

  final String? description;

  @override
  Widget build(BuildContext context) {
    if (description == null || description!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'ABOUT',
            style: theme.textTheme.bodySmall?.copyWith(
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a "FORM TIPS" section header with a bulleted list of tips.
///
/// Splits [formTips] on `\n`, trims each line, and filters out empty lines.
/// Collapses to nothing when [formTips] is null or empty after filtering.
class ExerciseFormTipsSection extends StatelessWidget {
  const ExerciseFormTipsSection({super.key, required this.formTips});

  final String? formTips;

  @override
  Widget build(BuildContext context) {
    if (formTips == null || formTips!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final tips = formTips!
        .split('\n')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (tips.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'FORM TIPS',
            style: theme.textTheme.bodySmall?.copyWith(
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(tips.length, (index) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tips[index],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
