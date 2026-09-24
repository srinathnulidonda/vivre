// lib/api/shared/shared_api.dart
import 'package:dio/dio.dart';

import '../api_exception.dart';
import '../config.dart';

class TimelineEntry {
  final String itemType;
  final String id;
  final String title;
  final DateTime? startAt;
  final DateTime? endAt;
  final Map<String, dynamic>? itemMetadata;

  const TimelineEntry({
    required this.itemType,
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.itemMetadata,
  });

  factory TimelineEntry.fromJson(Map<String, dynamic> json) {
    return TimelineEntry(
      itemType: json['item_type'] as String,
      id: json['id'] as String,
      title: json['title'] as String,
      startAt: json['start_at'] != null
          ? DateTime.parse(json['start_at'] as String)
          : null,
      endAt: json['end_at'] != null
          ? DateTime.parse(json['end_at'] as String)
          : null,
      itemMetadata:
          (json['item_metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }

  bool get isEvent => itemType == 'event';
  bool get isTask => itemType == 'task';
  bool get isTimeBlock => itemType == 'time_block';
  bool get isFocusSession => itemType == 'focus_session';

  String get timeLabel {
    final DateTime? start = startAt;
    if (start == null) return '';
    final DateTime local = start.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class SearchResult {
  final String resultType;
  final String id;
  final String title;
  final String? snippet;

  const SearchResult({
    required this.resultType,
    required this.id,
    required this.title,
    required this.snippet,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      resultType: json['result_type'] as String,
      id: json['id'] as String,
      title: json['title'] as String,
      snippet: json['snippet'] as String?,
    );
  }
}

class SharedApi {
  final Dio _dio;

  SharedApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<List<TimelineEntry>> timeline(DateTime date) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/timeline',
        queryParameters: {'date': _formatDate(date)},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) => TimelineEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<SearchResult>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/search',
        queryParameters: {'q': query, 'limit': limit, 'offset': offset},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['results'] as List<dynamic>? ?? const [];
      return items
          .map((e) => SearchResult.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}