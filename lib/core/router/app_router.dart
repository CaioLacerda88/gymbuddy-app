import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/providers/onboarding_provider.dart';
import '../../features/auth/providers/signup_state_provider.dart';
import '../../features/auth/ui/email_confirmation_screen.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/onboarding_screen.dart';
import '../../features/auth/ui/splash_screen.dart';
import '../../features/exercises/ui/create_exercise_screen.dart';
import '../../features/exercises/ui/exercise_detail_screen.dart';
import '../../features/exercises/ui/exercise_list_screen.dart';
import '../../features/workouts/models/active_workout_state.dart';
import '../../features/workouts/providers/workout_providers.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/workouts/ui/active_workout_screen.dart';
import '../../features/workouts/ui/home_screen.dart';
import '../../features/workouts/ui/workout_detail_screen.dart';
import '../../features/workouts/ui/workout_history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _RouterRefreshListenable(ref),
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.valueOrNull?.session != null;
      final needsOnboarding = ref.read(needsOnboardingProvider);
      final location = state.matchedLocation;

      // While auth is resolving, stay on splash.
      if (isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      // Not logged in → go to login (unless already there or on email confirmation).
      if (!isLoggedIn) {
        final hasSignupPending = ref.read(signupPendingEmailProvider) != null;
        if (location == '/email-confirmation' && hasSignupPending) return null;
        return location == '/login' ? null : '/login';
      }

      // Logged in → clear any pending signup state.
      ref.read(signupPendingEmailProvider.notifier).state = null;

      // Logged in but needs onboarding → go to onboarding.
      if (needsOnboarding && location != '/onboarding') {
        return '/onboarding';
      }

      // Logged in, on login or splash → go home.
      if (location == '/login' || location == '/splash') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/email-confirmation',
        builder: (context, state) => const EmailConfirmationScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/workout/active',
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => _ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/exercises',
            builder: (context, state) => const ExerciseListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateExerciseScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => ExerciseDetailScreen(
                  exerciseId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const WorkoutHistoryScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    WorkoutDetailScreen(workoutId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Notifies GoRouter when auth state changes so it re-evaluates redirects.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(this._ref) {
    _ref.listen(authStateProvider, (prev, next) => notifyListeners());
    _ref.listen(needsOnboardingProvider, (prev, next) => notifyListeners());
  }

  final Ref _ref;
}

class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold({required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/exercises')) return 1;
    if (location.startsWith('/history')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeState = ref.watch(activeWorkoutProvider).valueOrNull;

    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (activeState != null) _ActiveWorkoutBanner(state: activeState),
          NavigationBar(
            selectedIndex: _currentIndex(context),
            onDestinationSelected: (index) {
              final routes = ['/home', '/exercises', '/history', '/profile'];
              context.go(routes[index]);
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(
                icon: Icon(Icons.fitness_center),
                label: 'Exercises',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutBanner extends ConsumerWidget {
  const _ActiveWorkoutBanner({required this.state});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final elapsed = ref.watch(elapsedTimerProvider(state.workout.startedAt));

    return GestureDetector(
      onTap: () => context.go('/workout/active'),
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.85),
          border: Border(
            top: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              Icons.fitness_center,
              color: theme.colorScheme.onPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.workout.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              elapsed.when(
                data: _formatElapsed,
                loading: () => '...',
                error: (_, _) => '',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: theme.colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}
