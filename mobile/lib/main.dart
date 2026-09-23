// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/auth/auth_api.dart';
import 'api/config.dart';
import 'app/home/home.dart';
import 'app/navigation.dart';
import 'app/preferences.dart';
import 'auth/login.dart';
import 'onboarding/flow.dart';
import 'splash/vivre_splash.dart';
import 'themes/app-theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final Future<Widget> destination = _resolveDestination();

  runApp(VivreApp(destination: destination));
}

Future<Widget> _resolveDestination() async {
  await ApiConfig.load();
  ApiClient.instance.init();
  AuthRepository.instance.initialize(onSessionExpired: navigateToLogin);

  final AuthRepository auth = AuthRepository.instance;

  if (!await auth.isLoggedIn()) {
    final bool seen = await AppPreferences.hasSeenOnboarding();
    return seen ? const LoginPage() : const OnboardingFlow();
  }

  final VivreUser? cached = await auth.loadPersistedUser();
  if (cached != null) {
    unawaited(
      auth.fetchCurrentUser().catchError((_) => cached),
    );
    return HomePage(userName: cached.name);
  }

  try {
    final VivreUser user = await auth.fetchCurrentUser();
    return HomePage(userName: user.name);
  } catch (_) {
    return const LoginPage();
  }
}

class VivreApp extends StatelessWidget {
  final Future<Widget> destination;

  const VivreApp({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: vivreNavigatorKey,
      title: 'VIVRE',
      debugShowCheckedModeBanner: false,
      theme: VivreTheme.light,
      themeMode: ThemeMode.light,
      home: VivreSplash(
        onFinished: () => _navigateToDestination(destination),
      ),
    );
  }

  Future<void> _navigateToDestination(Future<Widget> future) async {
    final Widget destination = await future;
    final NavigatorState? navigator = vivreNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }
}