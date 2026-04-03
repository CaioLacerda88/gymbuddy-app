import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile_repository.dart';
import '../models/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final repo = ref.read(profileRepositoryProvider);
    return repo.getProfile(user.id);
  }

  Future<void> saveOnboardingProfile({
    required String displayName,
    required String fitnessLevel,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final repo = ref.read(profileRepositoryProvider);
    state = AsyncData(await repo.upsertProfile(
      userId: user.id,
      displayName: displayName,
      fitnessLevel: fitnessLevel,
    ));
  }

  Future<void> toggleWeightUnit() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final newUnit = current.weightUnit == 'kg' ? 'lbs' : 'kg';
    final repo = ref.read(profileRepositoryProvider);
    await repo.updateWeightUnit(user.id, newUnit);
    state = AsyncData(current.copyWith(weightUnit: newUnit));
  }
}
