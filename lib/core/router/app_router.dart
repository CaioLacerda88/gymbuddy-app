import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../connectivity/connectivity_provider.dart';
import '../local_storage/cache_refresh_provider.dart';
import '../offline/sync_service.dart';
import '../observability/sentry_init.dart' show sanitizeRouteName;
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
import '../../features/gamification/ui/saga_intro_gate.dart';
import '../../features/workouts/models/active_workout_state.dart';
import '../../features/workouts/providers/workout_providers.dart';
import '../../features/profile/ui/manage_data_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/routines/ui/create_routine_screen.dart';
import '../../features/routines/ui/routine_list_screen.dart';
import '../../features/personal_records/domain/pr_detection_service.dart';
import '../../features/personal_records/ui/pr_celebration_screen.dart';
import '../../features/personal_records/ui/pr_list_screen.dart';
import '../../features/workouts/ui/active_workout_screen.dart';
import '../../features/workouts/ui/home_screen.dart';
import '../../features/weekly_plan/ui/plan_management_screen.dart';
import '../../features/workouts/ui/workout_detail_screen.dart';
import '../../features/routines/models/routine.dart';
import '../../features/workouts/ui/workout_history_screen.dart';
import '../../shared/widgets/legal_doc_screen.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/pixel_image.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _RouterRefreshListenable(ref),
    observers: [
      SentryNavigatorObserver(
        enableAutoTransactions: false,
        setRouteNameAsTransaction: false,
        routeNameExtractor: sanitizeRouteName,
      ),
    ],
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.value?.session != null;
      final needsOnboarding = ref.read(needsOnboardingProvider);
      final location = state.matchedLocation;

      // While auth is resolving, stay on splash.
      if (isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      // Not logged in → go to login (unless already there, on email
      // confirmation, or viewing a public legal page).
      if (!isLoggedIn) {
        final hasSignupPending = ref.read(signupPendingEmailProvider) != null;
        if (location == '/email-confirmation' && hasSignupPending) return null;
        if (location == '/privacy-policy' || location == '/terms-of-service') {
          return null;
        }
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
        path: '/privacy-policy',
        builder: (context, state) => const LegalDocScreen(
          title: 'Privacy Policy',
          assetPath: 'assets/legal/privacy_policy.md',
        ),
      ),
      GoRoute(
        path: '/terms-of-service',
        builder: (context, state) => const LegalDocScreen(
          title: 'Terms of Service',
          assetPath: 'assets/legal/terms_of_service.md',
        ),
      ),
      GoRoute(
        path: '/workout/active',
        redirect: (context, state) {
          // Check in-memory state first (set immediately by startWorkout),
          // then fall back to Hive (persisted across restarts).
          final inMemory = ref.read(activeWorkoutProvider).value;
          final inHive = ref.read(hasActiveWorkoutProvider);
          if (inMemory == null && !inHive) return '/home';
          return null;
        },
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      GoRoute(
        path: '/pr-celebration',
        redirect: (context, state) {
          if (state.extra == null || state.extra is! Map<String, dynamic>) {
            return '/home';
          }
          return null;
        },
        builder: (context, state) {
          final extra = state.extra! as Map<String, dynamic>;
          return PRCelebrationScreen(
            result: extra['result'] as PRDetectionResult,
            exerciseNames: extra['exerciseNames'] as Map<String, String>,
            planPromptRoutineId: extra['planPromptRoutineId'] as String?,
            planPromptRoutineName: extra['planPromptRoutineName'] as String?,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) =>
            SagaIntroGate(child: _ShellScaffold(child: child)),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'history',
                builder: (context, state) => const WorkoutHistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => WorkoutDetailScreen(
                      workoutId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
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
            path: '/routines',
            builder: (context, state) => const RoutineListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) =>
                    CreateRoutineScreen(routine: state.extra as Routine?),
              ),
            ],
          ),
          GoRoute(
            path: '/records',
            builder: (context, state) => const PRListScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'manage-data',
                builder: (context, state) => const ManageDataScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/plan/week',
            builder: (context, state) => const PlanManagementScreen(),
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

  /// Returns the selected tab index, or -1 for non-tab routes (e.g. /records,
  /// /plan/week) so the bottom nav does not falsely highlight a tab.
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/exercises')) return 1;
    if (location.startsWith('/routines')) return 2;
    if (location.startsWith('/profile')) return 3;
    return -1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeState = ref.watch(activeWorkoutProvider).value;
    final isOnline = ref.watch(isOnlineProvider);
    ref.watch(cacheRefreshProvider);
    ref.watch(syncServiceProvider);
    final tabIndex = _currentIndex(context);
    // When on a non-tab route (e.g. /records, /plan/week), pass index 0 to
    // satisfy NavigationBar's range requirement but hide the indicator so no
    // tab appears active.
    final isOnTab = tabIndex >= 0;

    return Scaffold(
      body: Column(
        children: [
          if (!isOnline) const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (activeState != null) _ActiveWorkoutBanner(state: activeState),
          NavigationBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            indicatorColor: isOnTab
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            surfaceTintColor: Colors.transparent,
            selectedIndex: isOnTab ? tabIndex : 0,
            onDestinationSelected: (index) {
              const routes = ['/home', '/exercises', '/routines', '/profile'];
              final target = routes[index];
              // Guard against rapid tab switching: skip navigation when the
              // target route already matches the current location.
              final current = GoRouterState.of(context).matchedLocation;
              if (current == target) return;
              context.go(target);
            },
            destinations: [
              Semantics(
                container: true,
                identifier: 'nav-home',
                child: NavigationDestination(
                  icon: const _PixelNavIcon(
                    assetPath: 'assets/pixel/nav/home_inactive.png',
                  ),
                  selectedIcon: const _PixelNavIcon(
                    assetPath: 'assets/pixel/nav/home_active.png',
                  ),
                  label: AppLocalizations.of(context).navHome,
                  tooltip: '',
                ),
              ),
              Semantics(
                container: true,
                identifier: 'nav-exercises',
                child: NavigationDestination(
                  icon: const _PixelNavIcon(
                    assetPath: 'assets/pixel/nav/exercises_inactive.png',
                  ),
                  selectedIcon: const _PixelNavIcon(
                    assetPath: 'assets/pixel/nav/exercises_active.png',
                  ),
                  label: AppLocalizations.of(context).navExercises,
                  tooltip: '',
                ),
              ),
              Semantics(
                container: true,
                identifier: 'nav-routines',
                child: NavigationDestination(
                  icon: const _PixelNavIcon(
                    assetPath: 'assets/pixel/nav/routines_inactive.png',
                  ),
                  selectedIcon: const _PixelNavIcon(
                    assetPath: 'assets/pixel/nav/routines_active.png',
                  ),
                  label: AppLocalizations.of(context).navRoutines,
                  tooltip: '',
                ),
              ),
              Semantics(
                container: true,
                identifier: 'nav-profile',
                child: NavigationDestination(
                  icon: const _PixelNavIcon(
                    assetPath: 'assets/pixel/nav/profile_inactive.png',
                  ),
                  selectedIcon: const _PixelNavIcon(
                    assetPath: 'assets/pixel/nav/profile_active.png',
                  ),
                  label: AppLocalizations.of(context).navProfile,
                  tooltip: '',
                ),
              ),
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

    return Semantics(
      container: true,
      identifier: 'home-active-banner',
      button: true,
      label: 'Active workout: ${state.workout.name}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.go('/workout/active'),
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
                width: 2,
              ),
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

/// Fixed-size pixel nav icon (48dp square) for the bottom NavigationBar.
///
/// The semanticLabel is empty because the enclosing `NavigationDestination`
/// already exposes its own label to the accessibility tree; the icon is
/// decorative at that layer.
class _PixelNavIcon extends StatelessWidget {
  const _PixelNavIcon({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return PixelImage(assetPath, semanticLabel: '', width: 48, height: 48);
  }
}
