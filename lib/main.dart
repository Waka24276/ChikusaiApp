import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // flutterfire configureで自動生成されるファイル
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    // 匿名認証でサインインする
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint("Signed in with temporary account.");
  } catch (e) {
    debugPrint('Failed to sign in anonymously: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '千種祭 減点管理', // アプリのタイトル
      theme: ThemeData(
        // アプリ全体のカラーテーマを設定
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      // アプリの開始画面をLoginScreenに設定
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
