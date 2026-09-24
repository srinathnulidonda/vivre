// lib/api/reviews/reviews_api.dart
import 'package:dio/dio.dart';

import '../api_exception.dart';
import '../config.dart';

class DailyReviewSummary {
  final String id;
  final DateTime reviewDate;
  final String? wins;
  final String? blockers;
  final String? mood;
  final String? notes;

  const DailyReviewSummary({
    required this.id,
    required this.reviewDate,
    required this.wins,
    required this.blockers,
    required this.mood,
    required this.notes,
  });

  factory DailyReviewSummary.fromJson(Map<String, dynamic> json) {
    return DailyReviewSummary(
      id: json['id'] as String,
      reviewDate: DateTime.parse(json['review_date'] as String),
      wins: json['wins'] as String?,
      blockers: json['blockers'] as String?,
      mood: json['mood'] as String?,
      notes: json['notes'] as String?,
    );
  }

  bool get hasContent =>
      (wins?.isNotEmpty ?? false) ||
      (blockers?.isNotEmpty ?? false) ||
      (notes?.isNotEmpty ?? false);
}

class ReviewsApi {
  final Dio _dio;

  ReviewsApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  static String formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<DailyReviewSummary?> dailyReview(DateTime date) async {
    try {
      final Response<dynamic> response =
          await _dio.get('/reviews/daily/${formatDate(date)}');
      return DailyReviewSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioError(e);
    }
  }

  Future<DailyReviewSummary> upsertDailyReview({
    required DateTime reviewDate,
    String? wins,
    String? blockers,
    String? mood,
    String? notes,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/reviews/daily',
        data: {
          'review_date': formatDate(reviewDate),
          if (wins != null) 'wins': wins,
          if (blockers != null) 'blockers': blockers,
          if (mood != null) 'mood': mood,
          if (notes != null) 'notes': notes,
        },
      );
      return DailyReviewSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}