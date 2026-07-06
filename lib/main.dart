import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // flutterfire configureで自動生成されるファイル
import 'login_screen.dart';

Future<void> initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // 匿名認証でサインインする
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint("Signed in with temporary account.");
  } on FirebaseAuthException catch (e) {
    debugPrint('Failed to sign in anonymously: $e');
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
