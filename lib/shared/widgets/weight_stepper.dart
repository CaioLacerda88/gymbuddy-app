import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format/number_format.dart';
import '../../l10n/app_localizations.dart';

/// A reusable stepper widget for weight values.
///
/// Supports tap and long-press with progressive acceleration on the +/- buttons.
/// Initial hold delay of 400ms, then repeats at 150ms intervals.
/// Displays one decimal place when the value is fractional, integer otherwise.
class WeightStepper extends StatefulWidget {
  const WeightStepper({
    required this.value,
    required this.onChanged,
    this.increment = 2.5,
    this.unit = 'kg',
    super.key,
  });

  final double value;
  final double increment;
  final ValueChanged<double> onChanged;

  /// The weight unit label displayed in the input dialog and semantics.
  final String unit;

  @override
  State<WeightStepper> createState() => _WeightStepperState();
}

class _WeightStepperState extends State<WeightStepper> {
  Timer? _timer;

  void _decrement() {
    final next = widget.value - widget.increment;
    if (next >= 0) widget.onChanged(next);
  }

  void _increment() {
    widget.onChanged(widget.value + widget.increment);
  }

  void _startRepeating(VoidCallback action) {
    action();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      _timer = Timer.periodic(
        const Duration(milliseconds: 150),
        (_) => action(),
      );
    });
  }

  void _stopRepeating() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatWeight(double value, String locale) {
    return AppNumberFormat.weight(value, locale: locale);
  }

  /// Parses a user-entered weight accepting either `.` or `,` as the decimal
  /// separator so pt-BR users can type `80,5` naturally on the numeric keyboard.
  double? _parseWeight(String text) {
    final normalised = text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalised);
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showNumberInput() {
    final locale = Localizations.localeOf(context).languageCode;
    final controller = TextEditingController(
      text: _formatWeight(widget.value, locale),
    );
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final l10n = AppLocalizations.of(dialogCtx);
        return AlertDialog(
          title: Text(l10n.enterWeight),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(suffixText: widget.unit),
            onSubmitted: (text) {
              final parsed = _parseWeight(text);
              if (parsed != null) {
                widget.onChanged(parsed);
              }
              Navigator.of(dialogCtx).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final parsed = _parseWeight(controller.text);
                if (parsed != null) {
                  widget.onChanged(parsed);
                }
                Navigator.of(dialogCtx).pop();
              },
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final formatted = _formatWeight(widget.value, locale);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPressStart: (_) => _startRepeating(_decrement),
          onLongPressEnd: (_) => _stopRepeating(),
          onLongPressCancel: _stopRepeating,
          child: IconButton(
            onPressed: widget.value >= widget.increment ? _decrement : null,
            icon: const Icon(Icons.remove, size: 18),
            // BUG-019: 32x44 compresses below Material's 48dp tap minimum on
            // 360dp viewports (Moto G / Samsung A widths). Bumped to 40x48
            // so sweaty-thumb hits land on the right button mid-workout.
            constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        Flexible(
          child: Semantics(
            label:
                'Weight value: $formatted ${widget.unit}. Tap to enter weight.',
            button: true,
            child: GestureDetector(
              onTap: _showNumberInput,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 32),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatted,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                      shadows: [
                        Shadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          onLongPressStart: (_) => _startRepeating(_increment),
          onLongPressEnd: (_) => _stopRepeating(),
          onLongPressCancel: _stopRepeating,
          child: IconButton(
            onPressed: _increment,
            icon: const Icon(Icons.add, size: 18),
            // BUG-019: 32x44 compresses below Material's 48dp tap minimum on
            // 360dp viewports (Moto G / Samsung A widths). Bumped to 40x48
            // so sweaty-thumb hits land on the right button mid-workout.
            constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}
