import 'dart:async';

import 'package:flutter/material.dart';

/// A reusable stepper widget for weight values.
///
/// Supports tap and long-press (repeating every 100ms) on the +/- buttons.
/// Displays one decimal place when the value is fractional, integer otherwise.
class WeightStepper extends StatefulWidget {
  const WeightStepper({
    required this.value,
    required this.onChanged,
    this.increment = 2.5,
    super.key,
  });

  final double value;
  final double increment;
  final ValueChanged<double> onChanged;

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
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => action());
  }

  void _stopRepeating() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatWeight(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showNumberInput() {
    final controller = TextEditingController(text: _formatWeight(widget.value));
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter weight'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'kg'),
          onSubmitted: (text) {
            final parsed = double.tryParse(text);
            if (parsed != null && parsed >= 0) {
              widget.onChanged(parsed);
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null && parsed >= 0) {
                widget.onChanged(parsed);
              }
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPressStart: (_) => _startRepeating(_decrement),
          onLongPressEnd: (_) => _stopRepeating(),
          child: IconButton(
            onPressed: widget.value >= widget.increment ? _decrement : null,
            icon: const Icon(Icons.remove),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ),
        Semantics(
          label:
              'Weight value: ${_formatWeight(widget.value)} kg. Tap to enter weight.',
          button: true,
          child: GestureDetector(
            onTap: _showNumberInput,
            child: SizedBox(
              width: 72,
              child: Text(
                _formatWeight(widget.value),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  shadows: [
                    Shadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          onLongPressStart: (_) => _startRepeating(_increment),
          onLongPressEnd: (_) => _stopRepeating(),
          child: IconButton(
            onPressed: _increment,
            icon: const Icon(Icons.add),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ),
      ],
    );
  }
}
