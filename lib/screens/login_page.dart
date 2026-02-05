import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/session_store.dart';
import 'app_bootstrap.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _isLogin = true;

  Future<void> _goHome() async {
    // Reset role choice so user picks on next screen (or keep if you prefer)
    // await SessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppBootstrap()),
      (_) => false,
    );
  }

  Future<void> _authEmail() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final email = _email.text.trim();
      final pass = _pass.text.trim();
      if (email.isEmpty || pass.length < 6) {
        throw Exception('Enter a valid email and password (6+ chars).');
      }

      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      }

      await _goHome();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authAnon() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInAnonymously();
      await SessionStore.clear(); // start fresh
      await _goHome();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 18),
              const Text(
                'Donezy ✨',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Cute tasks • sweet rewards • happy home',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black.withOpacity(0.65)),
              ),
              const SizedBox(height: 22),

              _Card(
                child: Column(
                  children: [
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _pass,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 14),

                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 10),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _authEmail,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isLogin ? 'Login ✨' : 'Create Account 🎀'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin ? 'New here? Create account' : 'Already have an account? Login'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              TextButton(
                onPressed: _busy ? null : _authAnon,
                child: const Text('Try it without an account (Anonymous)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE6E8FF)),
        boxShadow: const [
          BoxShadow(blurRadius: 16, color: Color(0x14000000), offset: Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}
