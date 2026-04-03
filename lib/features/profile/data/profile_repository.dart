import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../models/profile.dart';

class ProfileRepository extends BaseRepository {
  const ProfileRepository(this._client);

  final supabase.SupabaseClient _client;

  Future<Profile?> getProfile(String userId) {
    return mapException(() async {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return Profile.fromJson(data);
    });
  }

  Future<Profile> upsertProfile({
    required String userId,
    String? displayName,
    String? fitnessLevel,
    String? weightUnit,
  }) {
    return mapException(() async {
      final updates = <String, dynamic>{
        'id': userId,
        // ignore: use_null_aware_elements
        if (displayName != null) 'display_name': displayName,
        // ignore: use_null_aware_elements
        if (fitnessLevel != null) 'fitness_level': fitnessLevel,
        // ignore: use_null_aware_elements
        if (weightUnit != null) 'weight_unit': weightUnit,
      };
      final data = await _client
          .from('profiles')
          .upsert(updates)
          .select()
          .single();
      return Profile.fromJson(data);
    });
  }

  Future<void> updateWeightUnit(String userId, String unit) {
    return mapException(() async {
      await _client
          .from('profiles')
          .update({'weight_unit': unit})
          .eq('id', userId);
    });
  }
}
