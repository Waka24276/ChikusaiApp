import 'dart:async';
import 'package:flutter/foundation.dart'; // kIsWebをインポート
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authをインポート
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferencesをインポート
import 'dart:html' as html; // Webでのみ利用
 
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  // ★ 変更点: ログイン成功時にユーザー名を保存し、ホーム画面に遷移する
  Future<void> _onLoginSuccess(String username) async {
    if (!mounted) return;
    // ユーザー名を永続化
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username.trim());

    Navigator.pushReplacement(
      context, // mountedチェック後の安全なcontext
      MaterialPageRoute(builder: (context) => HomeScreen(username: username.trim())),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      // 処理を擬似的に遅らせて、操作感を与える
      await Future.delayed(const Duration(milliseconds: 500));

      const String correctPassword = 'chigusa1516';

      // 安全な文字列比較を行う
      // 通常の '==' 比較は、文字が違うとすぐにfalseを返すため、処理時間の差からパスワードを推測される
      // タイミング攻撃のリスクをわずかに含みます。
      // この方法は、文字列の長さを比較してから、すべての文字を比較するため、より安全です。
      bool isPasswordCorrect = true;
      final a = _passwordController.text.trim();
      final b = correctPassword;
      if (a.length != b.length) {
        isPasswordCorrect = false;
      } else {
        for (int i = 0; i < a.length; i++) {
          if (a[i] != b[i]) isPasswordCorrect = false;
        }
      }
      if (isPasswordCorrect) {
        // パスワードが一致したらホーム画面へ
        try {
          // ログイン成功時にFirebaseへ匿名認証を行う
          // 既存のセッションがあれば一度サインアウトして、クリーンな状態で再認証する
          if (FirebaseAuth.instance.currentUser != null) {
            await FirebaseAuth.instance.signOut();
            debugPrint("Signed out previous session.");
          }
          await FirebaseAuth.instance.signInAnonymously();
          debugPrint("Authenticated with temporary account.");
          // ★ 変更点: 認証とユーザー名保存が完了してから画面遷移
          await _onLoginSuccess(_nameController.text);
        } catch (e) {
          debugPrint('Firebase authentication failed: $e');
          // 認証に失敗した場合は、エラーメッセージを表示して処理を中断
          if (mounted) {
            setState(() {
              _errorMessage = '認証に失敗しました。接続を確認してください。';
              _isLoading = false; // ★ 修正点: エラー時もローディングを解除
            });
          }
        }
      } else {
        // パスワードが違ったらエラーメッセージを表示
        if (mounted) {
          setState(() {
            _errorMessage = 'パスワードが正しくありません。';
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                keyboardType: TextInputType.text,
                autofillHints: const [AutofillHints.username],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '名前を入力してくださいっ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ログイン'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}