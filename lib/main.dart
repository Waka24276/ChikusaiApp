import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // flutterfire configureで自動生成されるファイル
import 'home_screen.dart';
import 'login_screen.dart';

Future<void> initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase初期化エラー: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '千種祭 減点管理アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: StreamBuilder<User?>(
        initialData: null,
        stream: Firebase.apps.isNotEmpty
            ? FirebaseAuth.instance.authStateChanges()
            : Stream<User?>.empty(),
        builder: (context, authSnapshot) {
          if (authSnapshot.hasData) {
            final user = authSnapshot.data!;
            final username = user.displayName ?? user.email?.split('@').first ?? '不明';
            return HomeScreen(username: username);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
