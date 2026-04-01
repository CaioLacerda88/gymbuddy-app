import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../models/exercise.dart';
import '../providers/exercise_providers.dart'
    show exerciseListProvider, exerciseRepositoryProvider;

class CreateExerciseScreen extends ConsumerStatefulWidget {
  const CreateExerciseScreen({super.key});

  @override
  ConsumerState<CreateExerciseScreen> createState() =>
      _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends ConsumerState<CreateExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  MuscleGroup? _selectedMuscleGroup;
  EquipmentType? _selectedEquipmentType;
  bool _isLoading = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (_nameError != null) return _nameError;
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _nameError = null);

    if (_selectedMuscleGroup == null || _selectedEquipmentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a muscle group and equipment type'),
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please log in again.'),
            ),
          );
          context.go('/login');
        }
        return;
      }
      await ref
          .read(exerciseRepositoryProvider)
          .createExercise(
            name: _nameController.text.trim(),
            muscleGroup: _selectedMuscleGroup!,
            equipmentType: _selectedEquipmentType!,
            userId: userId,
          );

      // Invalidate the exercise list to trigger a refresh.
      _invalidateExerciseList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise created successfully')),
        );
        context.pop();
      }
    } on ValidationException catch (e) {
      setState(() => _nameError = e.message);
      _formKey.currentState?.validate();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _invalidateExerciseList() {
    ref.invalidate(exerciseListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Exercise'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Exercise Name',
                  controller: _nameController,
                  validator: _validateName,
                  textInputAction: TextInputAction.done,
                  prefixIcon: Icons.fitness_center,
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                ),
                const SizedBox(height: 24),
                Text('Muscle Group', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _SelectableGrid<MuscleGroup>(
                  values: MuscleGroup.values,
                  selected: _selectedMuscleGroup,
                  onSelected: (v) => setState(() => _selectedMuscleGroup = v),
                  labelFor: (v) => v.displayName,
                  iconFor: (v) => v.icon,
                  semanticPrefix: 'Muscle group',
                ),
                const SizedBox(height: 24),
                Text('Equipment Type', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _SelectableGrid<EquipmentType>(
                  values: EquipmentType.values,
                  selected: _selectedEquipmentType,
                  onSelected: (v) => setState(() => _selectedEquipmentType = v),
                  labelFor: (v) => v.displayName,
                  iconFor: (v) => v.icon,
                  semanticPrefix: 'Equipment type',
                ),
                const SizedBox(height: 32),
                GradientButton(
                  label: 'CREATE EXERCISE',
                  onPressed: _isLoading ? null : _submit,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectableGrid<T> extends StatelessWidget {
  const _SelectableGrid({
    required this.values,
    required this.selected,
    required this.onSelected,
    required this.labelFor,
    required this.iconFor,
    required this.semanticPrefix,
  });

  final List<T> values;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelFor;
  final IconData Function(T) iconFor;
  final String semanticPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = selected == value;
        return _SelectableCard(
          label: labelFor(value),
          icon: iconFor(value),
          isSelected: isSelected,
          onTap: () => onSelected(value),
          semanticLabel: '$semanticPrefix: ${labelFor(value)}',
        );
      }).toList(),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Semantics(
      label: semanticLabel,
      selected: isSelected,
      child: Material(
        color: isSelected
            ? primary.withValues(alpha: 0.15)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64, minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? primary : theme.colorScheme.onSurface,
                  weight: 600,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isSelected ? primary : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
