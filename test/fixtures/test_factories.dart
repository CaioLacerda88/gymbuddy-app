// Factory classes for generating test data as Map<String, dynamic>.
// These will be replaced with Freezed model factories once models are generated.

class TestExerciseFactory {
  static Map<String, dynamic> create({
    String? id,
    String? name,
    String? muscleGroup,
    String? equipmentType,
    bool? isDefault,
    String? userId,
    String? deletedAt,
    String? createdAt,
  }) {
    return {
      'id': id ?? 'exercise-001',
      'name': name ?? 'Bench Press',
      'muscle_group': muscleGroup ?? 'chest',
      'equipment_type': equipmentType ?? 'barbell',
      'is_default': isDefault ?? true,
      'user_id': userId,
      'deleted_at': deletedAt,
      'created_at': createdAt ?? '2026-01-01T00:00:00Z',
    };
  }
}

class TestWorkoutFactory {
  static Map<String, dynamic> create({
    String? id,
    String? userId,
    String? name,
    String? startedAt,
    String? finishedAt,
    int? durationSeconds,
    bool? isActive,
    String? notes,
    String? createdAt,
  }) {
    return {
      'id': id ?? 'workout-001',
      'user_id': userId ?? 'user-001',
      'name': name ?? 'Push Day',
      'started_at': startedAt ?? '2026-01-01T10:00:00Z',
      'finished_at': finishedAt ?? '2026-01-01T11:00:00Z',
      'duration_seconds': durationSeconds ?? 3600,
      'is_active': isActive ?? false,
      'notes': notes,
      'created_at': createdAt ?? '2026-01-01T10:00:00Z',
    };
  }
}

class TestProfileFactory {
  static Map<String, dynamic> create({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? fitnessLevel,
    String? createdAt,
  }) {
    return {
      'id': id ?? 'user-001',
      'username': username ?? 'testuser',
      'display_name': displayName ?? 'Test User',
      'avatar_url': avatarUrl,
      'fitness_level': fitnessLevel ?? 'beginner',
      'created_at': createdAt ?? '2026-01-01T00:00:00Z',
    };
  }
}

class TestWorkoutExerciseFactory {
  static Map<String, dynamic> create({
    String? id,
    String? workoutId,
    String? exerciseId,
    int? order,
    int? restSeconds,
  }) {
    return {
      'id': id ?? 'we-001',
      'workout_id': workoutId ?? 'workout-001',
      'exercise_id': exerciseId ?? 'exercise-001',
      'order': order ?? 1,
      'rest_seconds': restSeconds,
    };
  }
}

class TestSetFactory {
  static Map<String, dynamic> create({
    String? id,
    String? workoutExerciseId,
    int? setNumber,
    int? reps,
    double? weight,
    int? rpe,
    String? notes,
    bool? isCompleted,
    String? createdAt,
  }) {
    return {
      'id': id ?? 'set-001',
      'workout_exercise_id': workoutExerciseId ?? 'we-001',
      'set_number': setNumber ?? 1,
      'reps': reps ?? 10,
      'weight': weight ?? 60.0,
      'rpe': rpe,
      'notes': notes,
      'is_completed': isCompleted ?? true,
      'created_at': createdAt ?? '2026-01-01T10:05:00Z',
    };
  }
}
