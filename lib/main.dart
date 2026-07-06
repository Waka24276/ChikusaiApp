import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

void main() async {
    // Flutterアプリの初期化を保証
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebaseの初期化
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // エラーが発生した場合はデバッグコンソールに出力
    debugPrint('Firebase initialization failed: $e');
  }

  // アプリを起動
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '文化祭 減点管理', 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      // 名前付きルートを定義
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
