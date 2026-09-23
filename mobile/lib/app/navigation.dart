// lib/app/navigation.dart
import 'package:flutter/material.dart';

import '../auth/login.dart';

final GlobalKey<NavigatorState> vivreNavigatorKey = GlobalKey<NavigatorState>();

void navigateToLogin() {
  vivreNavigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}