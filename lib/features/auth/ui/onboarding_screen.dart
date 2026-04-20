import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/device/platform_info.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../analytics/data/models/analytics_event.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/auth_providers.dart';
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
  int _trainingFrequency = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pleaseEnterName)));
      }
      return;
    }
    try {
      await ref
          .read(profileProvider.notifier)
          .saveOnboardingProfile(
            displayName: name,
            fitnessLevel: _fitnessLevel,
            trainingFrequencyPerWeek: _trainingFrequency,
          );
      ref.read(needsOnboardingProvider.notifier).state = false;

      // Fire analytics — best-effort, not awaited so it can't block navigation.
      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId != null) {
        unawaited(
          ref
              .read(analyticsRepositoryProvider)
              .insertEvent(
                userId: userId,
                event: AnalyticsEvent.onboardingCompleted(
                  fitnessLevel: _fitnessLevel,
                  trainingFrequency: _trainingFrequency,
                ),
                platform: currentPlatform(),
                appVersion: currentAppVersion(),
              ),
        );
      }

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToSaveProfile)));
      }
    }
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
                children: List.generate(2, (index) {
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
                    trainingFrequency: _trainingFrequency,
                    onTrainingFrequencyChanged: (freq) {
                      setState(() => _trainingFrequency = freq);
                    },
                    onFinish: _finishOnboarding,
                    onBack: _previousPage,
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
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Wrap passive content in a semantics boundary so it does not
          // merge into the GradientButton's semantics node (which would
          // drop the button's `identifier` in the DOM).
          Semantics(
            container: true,
            child: Column(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Semantics(
                  container: true,
                  identifier: 'onboarding-welcome',
                  child: Text(
                    l10n.onboardingHeadline,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.onboardingSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: l10n.getStarted,
              onPressed: onNext,
              semanticsIdentifier: 'onboarding-get-started',
            ),
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
    required this.trainingFrequency,
    required this.onTrainingFrequencyChanged,
    required this.onFinish,
    required this.onBack,
  });

  final TextEditingController nameController;
  final String fitnessLevel;
  final ValueChanged<String> onFitnessLevelChanged;
  final int trainingFrequency;
  final ValueChanged<int> onTrainingFrequencyChanged;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  static const _fitnessLevels = ['beginner', 'intermediate', 'advanced'];
  static const _frequencyOptions = [2, 3, 4, 5, 6];

  String _fitnessLevelLabel(String level, AppLocalizations l10n) {
    return switch (level) {
      'beginner' => l10n.fitnessLevelBeginner,
      'intermediate' => l10n.fitnessLevelIntermediate,
      'advanced' => l10n.fitnessLevelAdvanced,
      _ => level[0].toUpperCase() + level.substring(1),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            l10n.setupProfile,
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tellUsAboutYourself,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          AppTextField(
            label: l10n.displayName,
            controller: nameController,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.person_outlined,
            maxLength: 50,
            showCounter: false,
            semanticsIdentifier: 'onboarding-display-name',
          ),
          const SizedBox(height: 24),
          Text(l10n.fitnessLevel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: _fitnessLevels.map((level) {
              final isSelected = level == fitnessLevel;
              return Semantics(
                container: true,
                identifier: 'onboarding-$level',
                child: ChoiceChip(
                  label: Text(_fitnessLevelLabel(level, l10n)),
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
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(l10n.howOftenTrain, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.weeklyGoalHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: _frequencyOptions.map((freq) {
              final isSelected = freq == trainingFrequency;
              return ChoiceChip(
                label: Text('${freq}x'),
                selected: isSelected,
                onSelected: (_) => onTrainingFrequencyChanged(freq),
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
          GradientButton(
            label: l10n.letsGo,
            onPressed: onFinish,
            semanticsIdentifier: 'onboarding-lets-go',
          ),
          const SizedBox(height: 12),
          Center(
            child: Semantics(
              container: true,
              identifier: 'onboarding-back',
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l10n.back),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
