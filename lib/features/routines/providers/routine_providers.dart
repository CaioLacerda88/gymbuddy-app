import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/routine_repository.dart';

export 'notifiers/routine_list_notifier.dart';

/// Provides the [RoutineRepository] singleton.
final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository(Supabase.instance.client);
});
