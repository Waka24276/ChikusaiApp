import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _autoLoginTimer;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  // アプリ起動時にFirebaseのログイン状態をチェックする
  Future<void> _autoLogin() async {
    _autoLoginTimer?.cancel();
    _autoLoginTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && FirebaseAuth.instance.currentUser != null) {
        _navigateToHome(FirebaseAuth.instance.currentUser!);
      }
    });
  }

  void _navigateToHome(User user) {
    if (!mounted) return;
    // ユーザー名が設定されていなければメールアドレスの@より前を使う
    final username = user.displayName ?? user.email?.split('@').first ?? '不明';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(username: username)),
    );
  }

  @override
  void dispose() {
    _autoLoginTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Firebase Authでログイン試行
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (credential.user != null) {
          if (_rememberMe) {
            // SharedPreferencesはログイン状態の永続化には使わない
            // Firebase SDKが自動でセッションを管理してくれる
          }
          _navigateToHome(credential.user!);
        }
      } on FirebaseAuthException catch (e) {
        // エラーハンドリング
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _errorMessage = 'メールアドレスまたはパスワードが正しくありません。';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'メールアドレスの形式が正しくありません。';
        } else {
          _errorMessage = 'エラーが発生しました: ${e.message}';
        }
      } catch (e) {
        _errorMessage = '予期せぬエラーが発生しました。';
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
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
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'メールアドレスを入力してください';
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
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('ログイン状態を保持する'),
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
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