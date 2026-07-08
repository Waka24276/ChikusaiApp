import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'home_screen.dart'; // HomeScreenをインポート

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '文化祭 減点Web', 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      // StreamBuilderを使用して認証状態を監視
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 接続状態を待機
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // ユーザーがログインしている（匿名認証含む）場合
          if (snapshot.hasData && snapshot.data != null) {
            // SharedPreferencesからユーザー名を取得してホーム画面へ
            return FutureBuilder<String>(
              future: _getUsername(),
              builder: (context, nameSnapshot) {
                if (nameSnapshot.connectionState == ConnectionState.done && nameSnapshot.hasData) {
                  return HomeScreen(username: nameSnapshot.data!);
                }
                // ユーザー名取得中もローディング表示
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              },
            );
          }

          // ユーザーがログインしていない場合はログイン画面へ
          return const LoginScreen();
        },
      ),
    );
  }

  // SharedPreferencesから保存されたユーザー名を取得するヘルパー関数
  Future<String> _getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    // 'username' キーで保存された値を取得。なければ空文字を返す。
    return prefs.getString('username') ?? '';
  }
}
