import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../../exercises/models/exercise.dart';
import '../data/pr_repository.dart';
import '../domain/pr_detection_service.dart';
import '../models/personal_record.dart';

/// A personal record enriched with exercise name and equipment type.
typedef PRWithExercise = ({
  PersonalRecord record,
  String exerciseName,
  EquipmentType equipmentType,
});

/// Provides the [PRRepository] singleton.
final prRepositoryProvider = Provider<PRRepository>((ref) {
  return PRRepository(Supabase.instance.client);
});

/// Provides the [PRDetectionService] singleton.
final prDetectionServiceProvider = Provider<PRDetectionService>((ref) {
  return PRDetectionService();
});

/// Fetches all personal records for the current user.
/// Used by the PR list screen.
final prListProvider = FutureProvider<List<PersonalRecord>>((ref) {
  final repo = ref.watch(prRepositoryProvider);
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return [];
  return repo.getRecordsForUser(user.id);
});

/// Fetches PRs for a specific exercise (by exercise ID).
/// Used by exercise detail screen.
final exercisePRsProvider = FutureProvider.family<List<PersonalRecord>, String>(
  (ref, exerciseId) async {
    final repo = ref.watch(prRepositoryProvider);
    final records = await repo.getRecordsForExercises([exerciseId]);
    return records[exerciseId] ?? [];
  },
);

/// Fetches all PRs with exercise details for the PR list screen.
final prListWithExercisesProvider = FutureProvider<List<PRWithExercise>>((ref) {
  final repo = ref.watch(prRepositoryProvider);
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return [];
  return repo.getRecordsWithExercises(user.id);
});
