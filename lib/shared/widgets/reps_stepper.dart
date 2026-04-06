import 'dart:async';

import 'package:flutter/material.dart';

/// A reusable stepper widget for rep counts.
///
/// Supports tap and long-press with progressive acceleration on the +/- buttons.
/// Initial hold delay of 400ms, then repeats at 150ms intervals.
/// Displays integer values only.
class RepsStepper extends StatefulWidget {
  const RepsStepper({
    required this.value,
    required this.onChanged,
    this.increment = 1,
    super.key,
  });

  final int value;
  final int increment;
  final ValueChanged<int> onChanged;

  @override
  State<RepsStepper> createState() => _RepsStepperState();
}

class _RepsStepperState extends State<RepsStepper> {
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showNumberInput() {
    final controller = TextEditingController(text: widget.value.toString());
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter reps'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          onSubmitted: (text) {
            final parsed = int.tryParse(text);
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
              final parsed = int.tryParse(controller.text);
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
            icon: const Icon(Icons.remove, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 44),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        Flexible(
          child: Semantics(
            label: 'Reps value: ${widget.value}. Tap to enter reps.',
            button: true,
            child: GestureDetector(
              onTap: _showNumberInput,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 28),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.value.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
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
          child: IconButton(
            onPressed: _increment,
            icon: const Icon(Icons.add, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 44),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}
