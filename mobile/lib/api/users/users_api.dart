// lib/api/users/users_api.dart
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api_exception.dart';
import '../config.dart';

class GoogleConnectionInfo {
  final String id;
  final String googleAccountEmail;
  final String scope;
  final DateTime tokenExpiresAt;

  const GoogleConnectionInfo({
    required this.id,
    required this.googleAccountEmail,
    required this.scope,
    required this.tokenExpiresAt,
  });

  factory GoogleConnectionInfo.fromJson(Map<String, dynamic> json) {
    return GoogleConnectionInfo(
      id: json['id'] as String,
      googleAccountEmail: json['google_account_email'] as String,
      scope: json['scope'] as String? ?? '',
      tokenExpiresAt: DateTime.parse(json['token_expires_at'] as String),
    );
  }
}

class AvatarUploadResult {
  final String avatarUrl;
  final String avatarPublicId;

  const AvatarUploadResult({
    required this.avatarUrl,
    required this.avatarPublicId,
  });

  factory AvatarUploadResult.fromJson(Map<String, dynamic> json) {
    return AvatarUploadResult(
      avatarUrl: json['avatar_url'] as String,
      avatarPublicId: json['avatar_public_id'] as String,
    );
  }
}

class UsersApi {
  final Dio _dio;

  UsersApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<void> updateProfile({String? name, String? timezone}) async {
    try {
      await _dio.patch(
        '/users/me',
        data: {
          if (name != null) 'name': name,
          if (timezone != null) 'timezone': timezone,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<AvatarUploadResult> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
    required String filename,
  }) async {
    try {
      final FormData form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
      });
      final Response<dynamic> response = await _dio.post(
        '/users/me/avatar',
        data: form,
      );
      return AvatarUploadResult.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteAvatar() async {
    try {
      await _dio.delete('/users/me/avatar');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<GoogleConnectionInfo?> getGoogleConnection() async {
    try {
      final Response<dynamic> response = await _dio.get('/users/me/google');
      return GoogleConnectionInfo.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioError(e);
    }
  }

  Future<String> getGoogleAuthorizeUrl() async {
    try {
      final Response<dynamic> response =
          await _dio.get('/users/me/google/authorize-url');
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      return data['authorization_url'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> disconnectGoogle() async {
    try {
      await _dio.delete('/users/me/google');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}