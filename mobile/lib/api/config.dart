// lib/api/config.dart
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  ApiConfig._();

  static String baseUrl = 'https://vivre-knva.onrender.com';
  static int timeoutSeconds = 15;
  static bool enableLogging = false;
  static String googleWebClientId = '';

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      baseUrl = dotenv.get('API_BASE_URL', fallback: baseUrl);
      timeoutSeconds =
          int.tryParse(dotenv.get('API_TIMEOUT_SECONDS', fallback: '15')) ?? 15;
      enableLogging =
          dotenv.get('ENABLE_API_LOGGING', fallback: 'false') == 'true';
      googleWebClientId = dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: '');
    } catch (_) {}
  }
}

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  late final Dio dio;
  bool _initialized = false;

  void init() {
    if (_initialized) return;

    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: Duration(seconds: ApiConfig.timeoutSeconds),
        receiveTimeout: Duration(seconds: ApiConfig.timeoutSeconds),
        sendTimeout: Duration(seconds: ApiConfig.timeoutSeconds),
        headers: const {'Content-Type': 'application/json'},
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    if (ApiConfig.enableLogging) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          logPrint: (object) => print('[VIVRE_API] $object'),
        ),
      );
    }

    _initialized = true;
  }
}