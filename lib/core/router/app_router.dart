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
      ShellRoute(
        builder: (context, state, child) => _ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const _TabPlaceholder(title: 'Home'),
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
            builder: (context, state) =>
                const _TabPlaceholder(title: 'History'),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) =>
                const _TabPlaceholder(title: 'Profile'),
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

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return switch (location) {
      '/exercises' => 1,
      '/history' => 2,
      '/profile' => 3,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
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
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}
