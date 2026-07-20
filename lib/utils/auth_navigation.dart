import 'package:flutter/material.dart';
import 'package:prism/models/auth_gate.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/screens/home_screen.dart';
import 'package:prism/screens/secure_account_screen.dart';

void navigateAfterAuthentication(
  BuildContext context,
  AuthProvider auth, {
  bool clearStack = false,
}) {
  if (!context.mounted) return;

  Route<void> route;
  switch (auth.authGate) {
    case AuthGate.migrateAccount:
      route = MaterialPageRoute(builder: (_) => const SecureAccountScreen());
    case AuthGate.verifyEmail:
    case AuthGate.none:
      // Email verification is not required after registration; only forgot-
      // password uses an email reset link. Treat stale verifyEmail gates as home.
      route = PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            HomeScreen(key: HomeScreen.homeScreenKey),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
  }

  if (clearStack) {
    Navigator.of(context).pushAndRemoveUntil(route, (r) => false);
  } else {
    Navigator.of(context).pushReplacement(route);
  }
}
