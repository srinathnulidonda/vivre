// lib/api/auth/auth_api.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_exception.dart';
import '../config.dart';
import 'token_storage.dart';

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}

class MessageResponse {
  final String message;

  const MessageResponse({required this.message});

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(message: json['message'] as String? ?? '');
  }
}

class VivreUser {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String timezone;
  final bool isEmailVerified;
  final DateTime createdAt;

  const VivreUser({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.timezone,
    required this.isEmailVerified,
    required this.createdAt,
  });

  factory VivreUser.fromJson(Map<String, dynamic> json) {
    return VivreUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC',
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'timezone': timezone,
      'is_email_verified': isEmailVerified,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class GoogleAuthService {
  GoogleAuthService._internal();
  static final GoogleAuthService instance = GoogleAuthService._internal();

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: ApiConfig.googleWebClientId,
    scopes: const <String>['email'],
  );

  Future<String?> signInAndGetIdToken() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null;

      final GoogleSignInAuthentication authentication =
          await account.authentication;
      return authentication.idToken;
    } catch (_) {
      await _googleSignIn.signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

class AuthApi {
  final Dio _dio;

  AuthApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  static final Options _publicOptions = Options(extra: {'skipAuth': true});

  Future<TokenResponse> signup({
    required String email,
    required String password,
    required String name,
    required String timezone,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'name': name,
          'timezone': timezone,
        },
        options: _publicOptions,
      );
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TokenResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: _publicOptions,
      );
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TokenResponse> loginWithGoogle({required String idToken}) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/auth/google',
        data: {'id_token': idToken},
        options: _publicOptions,
      );
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TokenResponse> refresh({required String refreshToken}) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: _publicOptions,
      );
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> logout({required String refreshToken}) async {
    try {
      await _dio.post(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
        options: _publicOptions,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<MessageResponse> requestEmailVerification({
    required String email,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/auth/email/verify/request',
        data: {'email': email},
        options: _publicOptions,
      );
      return MessageResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<MessageResponse> confirmEmailVerification({
    required String email,
    required String otp,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/auth/email/verify',
        data: {'email': email, 'otp': otp},
        options: _publicOptions,
      );
      return MessageResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<MessageResponse> forgotPassword({required String email}) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/auth/password/forgot',
        data: {'email': email},
        options: _publicOptions,
      );
      return MessageResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<MessageResponse> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/auth/password/reset',
        data: {'email': email, 'otp': otp, 'new_password': newPassword},
        options: _publicOptions,
      );
      return MessageResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<VivreUser> fetchCurrentUser() async {
    try {
      final Response<dynamic> response = await _dio.get('/users/me');
      return VivreUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

enum _RefreshOutcome { refreshed, sessionInvalid, transientFailure }

class _AuthInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorage tokenStorage;
  final Future<TokenResponse?> Function(String refreshToken) onRefresh;
  final Future<void> Function() onSessionExpired;

  Future<_RefreshOutcome>? _refreshFuture;

  _AuthInterceptor({
    required this.dio,
    required this.tokenStorage,
    required this.onRefresh,
    required this.onSessionExpired,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final String? accessToken = await tokenStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final bool isUnauthorized = err.response?.statusCode == 401;
    final bool skipAuth = err.requestOptions.extra['skipAuth'] == true;
    final bool alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (!isUnauthorized || skipAuth || alreadyRetried) {
      handler.next(err);
      return;
    }

    final _RefreshOutcome outcome = await _refreshToken();

    if (outcome == _RefreshOutcome.refreshed) {
      final String? accessToken = await tokenStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        try {
          final RequestOptions retryOptions = err.requestOptions;
          retryOptions.extra['retried'] = true;
          retryOptions.headers['Authorization'] = 'Bearer $accessToken';
          final Response<dynamic> response = await dio.fetch(retryOptions);
          handler.resolve(response);
          return;
        } catch (_) {}
      }
    }

    if (outcome == _RefreshOutcome.sessionInvalid) {
      await tokenStorage.clear();
      await onSessionExpired();
    }

    handler.next(err);
  }

  Future<_RefreshOutcome> _refreshToken() {
    return _refreshFuture ??= _performRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<_RefreshOutcome> _performRefresh() async {
    try {
      final String? refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return _RefreshOutcome.sessionInvalid;
      }

      final TokenResponse? tokens = await onRefresh(refreshToken);
      if (tokens == null) return _RefreshOutcome.sessionInvalid;

      await tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return _RefreshOutcome.refreshed;
    } catch (_) {
      return _RefreshOutcome.transientFailure;
    }
  }
}

class AuthRepository {
  AuthRepository._internal();
  static final AuthRepository instance = AuthRepository._internal();

  static const String _cachedUserKey = 'vivre_cached_user';

  final AuthApi _authApi = AuthApi();
  final TokenStorage tokenStorage = TokenStorage();

  VivreUser? _cachedUser;
  bool _interceptorAttached = false;

  VivreUser? get currentUser => _cachedUser;

  void initialize({required VoidCallback onSessionExpired}) {
    if (_interceptorAttached) return;

    ApiClient.instance.dio.interceptors.add(
      _AuthInterceptor(
        dio: ApiClient.instance.dio,
        tokenStorage: tokenStorage,
        onRefresh: (refreshToken) async {
          try {
            return await _authApi.refresh(refreshToken: refreshToken);
          } on ApiException catch (e) {
            if (e.isUnauthorized) return null;
            rethrow;
          }
        },
        onSessionExpired: () async {
          _cachedUser = null;
          try {
            await _clearPersistedUser();
          } finally {
            onSessionExpired();
          }
        },
      ),
    );

    _interceptorAttached = true;
  }

  Future<VivreUser?> loadPersistedUser() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_cachedUserKey);
    if (raw == null) return null;
    try {
      final VivreUser user = VivreUser.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _cachedUser = user;
      return user;
    } catch (_) {
      await prefs.remove(_cachedUserKey);
      return null;
    }
  }

  Future<void> _persistUser(VivreUser user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUserKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearPersistedUser() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedUserKey);
  }

  Future<bool> isLoggedIn() => tokenStorage.hasTokens();

  Future<VivreUser> signup({
    required String email,
    required String password,
    required String name,
    required String timezone,
  }) async {
    final TokenResponse tokens = await _authApi.signup(
      email: email,
      password: password,
      name: name,
      timezone: timezone,
    );
    await tokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return _loadAndCacheCurrentUser();
  }

  Future<VivreUser> login({
    required String email,
    required String password,
  }) async {
    final TokenResponse tokens = await _authApi.login(
      email: email,
      password: password,
    );
    await tokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return _loadAndCacheCurrentUser();
  }

  Future<VivreUser?> signInWithGoogle() async {
    final String? idToken =
        await GoogleAuthService.instance.signInAndGetIdToken();
    if (idToken == null) return null;
    return loginWithGoogle(idToken: idToken);
  }

  Future<VivreUser> loginWithGoogle({required String idToken}) async {
    final TokenResponse tokens =
        await _authApi.loginWithGoogle(idToken: idToken);
    await tokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return _loadAndCacheCurrentUser();
  }

  Future<void> logout() async {
    final String? refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _authApi.logout(refreshToken: refreshToken);
      } catch (_) {}
    }
    try {
      await GoogleAuthService.instance.signOut();
    } catch (_) {}
    await tokenStorage.clear();
    _cachedUser = null;
    await _clearPersistedUser();
  }

  Future<MessageResponse> requestEmailVerification({required String email}) {
    return _authApi.requestEmailVerification(email: email);
  }

  Future<VivreUser> confirmEmailVerification({
    required String email,
    required String otp,
  }) async {
    await _authApi.confirmEmailVerification(email: email, otp: otp);
    return _loadAndCacheCurrentUser();
  }

  Future<MessageResponse> forgotPassword({required String email}) {
    return _authApi.forgotPassword(email: email);
  }

  Future<MessageResponse> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _authApi.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }

  Future<VivreUser> fetchCurrentUser() => _loadAndCacheCurrentUser();

  Future<VivreUser> _loadAndCacheCurrentUser() async {
    final VivreUser user = await _authApi.fetchCurrentUser();
    _cachedUser = user;
    await _persistUser(user);
    return user;
  }
}