import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'source.freezed.dart';
part 'source.g.dart';

@freezed
abstract class Source with _$Source {
  const factory Source({
    required String id,
    required String subjectId,
    String? topicId,
    String? chapterId,
    required SourceType type,
    required String title,
    String? filePath,
    String? url,
    int? currentPage,
    int? totalPages,
    double? progressPercent,
    String? notes,
    required DateTime addedAt,
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
}
