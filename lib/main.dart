import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const ProviderScope(
      // Riverpod wrapper
      child: LifeInSyncApp(),
    ),
  );
}

class LifeInSyncApp extends StatelessWidget {
  const LifeInSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeInSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(), // Start at login
      routes: {
        '/login': (_) => const LoginScreen(),
        '/otp': (_) => const OtpScreen(),
        // Add more routes as you build screens
      },
    );
  }
}
