// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import 'body_part.dart';

part 'title.freezed.dart';
part 'title.g.dart';

/// A title catalog entry — v1 surfaces only the per-body-part ladder (78
/// titles, every 5 ranks per body part). Character-level (7) and cross-build
/// (5) titles arrive in Phase 18e.
///
/// **Display copy is NOT on this model.** `name` and `flavor` resolve through
/// `AppLocalizations` keyed by [slug]:
///   * `title_{slug}_name`
///   * `title_{slug}_flavor`
///
/// This keeps the catalog pt-BR coverage in `app_pt.arb` (Brazilian gym voice,
/// not literal translation) and the structural data in `assets/rpg/titles_v1.json`.
///
/// `slug` is the join key with [`earned_titles.title_id`] in Postgres. The
/// `(slug, body_part, rank_threshold)` triple is stable forever — renaming or
/// re-thresholding a title would orphan everyone who unlocked it. Editorial
/// changes to display copy ship by editing the `.arb` files, not the catalog.
@freezed
abstract class Title with _$Title {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Title({
    required String slug,
    required BodyPart bodyPart,
    required int rankThreshold,
  }) = _Title;

  factory Title.fromJson(Map<String, dynamic> json) => _$TitleFromJson(json);
}
