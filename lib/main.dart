import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 匿名認証でサインインする
  // 既にサインイン済みの場合は再利用される
  await FirebaseAuth.instance.signInAnonymously();
  debugPrint("Firebase initialized and user signed in anonymously.");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '千種祭 減点管理',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      // アプリの開始画面をLoginScreenに設定
      initialRoute: '/login',
      routes: {
        // '/login' という名前の画面としてLoginScreenを登録
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
