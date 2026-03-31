import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Page 2: Profile setup state
  final _nameController = TextEditingController();
  String _fitnessLevel = 'beginner';

  // Page 3: Workout choice
  String? _workoutChoice;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() {
    // TODO: Save profile data to Supabase (will be wired in profile feature)
    ref.read(needsOnboardingProvider.notifier).state = false;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                children: List.generate(3, (index) {
                  final isActive = index <= _currentPage;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.2,
                              ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _WelcomePage(onNext: _nextPage),
                  _ProfileSetupPage(
                    nameController: _nameController,
                    fitnessLevel: _fitnessLevel,
                    onFitnessLevelChanged: (level) {
                      setState(() => _fitnessLevel = level);
                    },
                    onNext: _nextPage,
                  ),
                  _WorkoutChoicePage(
                    selectedChoice: _workoutChoice,
                    onChoiceChanged: (choice) {
                      setState(() => _workoutChoice = choice);
                    },
                    onFinish: _finishOnboarding,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Page 1: Welcome ---

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Track every rep,\nevery time',
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Log workouts, crush personal records, and build the physique you want.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: AppButton(label: 'GET STARTED', onPressed: onNext),
          ),
        ],
      ),
    );
  }
}

// --- Page 2: Profile Setup ---

class _ProfileSetupPage extends StatelessWidget {
  const _ProfileSetupPage({
    required this.nameController,
    required this.fitnessLevel,
    required this.onFitnessLevelChanged,
    required this.onNext,
  });

  final TextEditingController nameController;
  final String fitnessLevel;
  final ValueChanged<String> onFitnessLevelChanged;
  final VoidCallback onNext;

  static const _fitnessLevels = ['beginner', 'intermediate', 'advanced'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'Set up your profile',
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us a bit about yourself',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          AppTextField(
            label: 'Display name',
            controller: nameController,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.person_outlined,
          ),
          const SizedBox(height: 24),
          Text('Fitness level', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: _fitnessLevels.map((level) {
              final isSelected = level == fitnessLevel;
              return ChoiceChip(
                label: Text(level[0].toUpperCase() + level.substring(1)),
                selected: isSelected,
                onSelected: (_) => onFitnessLevelChanged(level),
                selectedColor: theme.colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          AppButton(label: 'NEXT', onPressed: onNext),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// --- Page 3: First Workout Choice ---

class _WorkoutChoicePage extends StatelessWidget {
  const _WorkoutChoicePage({
    required this.selectedChoice,
    required this.onChoiceChanged,
    required this.onFinish,
  });

  final String? selectedChoice;
  final ValueChanged<String> onChoiceChanged;
  final VoidCallback onFinish;

  static const _choices = [
    _WorkoutOption(
      id: 'full_body',
      title: 'Full Body Starter',
      subtitle: 'A balanced template to get going',
      icon: Icons.accessibility_new,
    ),
    _WorkoutOption(
      id: 'blank',
      title: 'Start Blank',
      subtitle: 'Build your own from scratch',
      icon: Icons.add_circle_outline,
    ),
    _WorkoutOption(
      id: 'browse',
      title: 'Browse Exercises',
      subtitle: 'Explore the exercise library first',
      icon: Icons.search,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'Your first workout',
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'How do you want to start?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ..._choices.map((option) {
            final isSelected = option.id == selectedChoice;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WorkoutChoiceCard(
                option: option,
                isSelected: isSelected,
                onTap: () => onChoiceChanged(option.id),
              ),
            );
          }),
          const Spacer(),
          AppButton(
            label: "LET'S GO",
            onPressed: selectedChoice != null ? onFinish : null,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _WorkoutOption {
  const _WorkoutOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _WorkoutChoiceCard extends StatelessWidget {
  const _WorkoutChoiceCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _WorkoutOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              size: 32,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
