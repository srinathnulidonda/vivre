// lib/api/api_exception.dart
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;

  const ApiException({
    this.statusCode,
    required this.code,
    required this.message,
  });

  bool get isRateLimited => statusCode == 429;
  bool get isConflict => statusCode == 409;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isValidationError => statusCode == 422 || code == 'validation_error';

  factory ApiException.fromDioError(DioException error) {
    final Response<dynamic>? response = error.response;

    if (response?.data is Map) {
      final Map<dynamic, dynamic> data = response!.data as Map;
      final dynamic errorField = data['error'];
      if (errorField is Map) {
        return ApiException(
          statusCode: response.statusCode,
          code: errorField['code']?.toString() ?? 'unknown_error',
          message: errorField['message']?.toString() ?? 'Something went wrong',
        );
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          code: 'timeout',
          message: 'The request timed out. Please check your connection and try again.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          code: 'connection_error',
          message: 'Unable to reach the server. Please check your internet connection.',
        );
      default:
        return const ApiException(
          code: 'unknown_error',
          message: 'Something went wrong. Please try again.',
        );
    }
  }

  @override
  String toString() => message;
}