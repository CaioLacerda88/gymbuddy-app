// Factory classes for generating test data as Map<String, dynamic>.
// These will be replaced with Freezed model factories once models are generated.

class TestExerciseFactory {
  static Map<String, dynamic> create({
    String? id,
    String? name,
    String? muscleGroup,
    String? equipmentType,
    bool? isDefault,
    String? imageStartUrl,
    String? imageEndUrl,
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
      'image_start_url': imageStartUrl,
      'image_end_url': imageEndUrl,
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
    String? setType,
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
      'set_type': setType ?? 'working',
      'notes': notes,
      'is_completed': isCompleted ?? true,
      'created_at': createdAt ?? '2026-01-01T10:05:00Z',
    };
  }
}

class TestActiveWorkoutStateFactory {
  static Map<String, dynamic> create({
    Map<String, dynamic>? workout,
    List<Map<String, dynamic>>? exercises,
    int? schemaVersion,
  }) {
    return {
      'workout': workout ?? TestWorkoutFactory.create(isActive: true),
      'exercises': exercises ?? [],
      'schema_version': schemaVersion ?? 1,
    };
  }

  static Map<String, dynamic> createWithExercises({
    Map<String, dynamic>? workout,
    int exerciseCount = 2,
    int setsPerExercise = 3,
  }) {
    final workoutData = workout ?? TestWorkoutFactory.create(isActive: true);

    final exercises = List.generate(exerciseCount, (i) {
      final weId = 'we-${i + 1}';
      final sets = List.generate(setsPerExercise, (j) {
        return TestSetFactory.create(
          id: 'set-$weId-${j + 1}',
          workoutExerciseId: weId,
          setNumber: j + 1,
        );
      });

      return {
        'workout_exercise': TestWorkoutExerciseFactory.create(
          id: weId,
          exerciseId: 'exercise-${i + 1}',
          order: i + 1,
        ),
        'sets': sets,
      };
    });

    return {
      'workout': workoutData,
      'exercises': exercises,
      'schema_version': 1,
    };
  }
}
