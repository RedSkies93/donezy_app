import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/session_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _signInOrCreateEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text.trim();

      if (email.isEmpty) throw Exception('Enter an email.');
      if (pass.length < 6) {
        throw Exception('Password must be at least 6 characters.');
      }

      try {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pass);
      } catch (_) {
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass);
      }

      await SessionStore.clearAll();
      // No navigation: AppBootstrap routes based on auth + session.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInAnonymous() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInAnonymously();
      await SessionStore.clearAll();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: Stack(
        children: [
          const _CuteBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  const _LogoHeader(),
                  const SizedBox(height: 14),
                  const _ValueProps(),
                  const SizedBox(height: 14),
                  _CuteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Parent login',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _input('Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          decoration: _input('Password'),
                        ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signInOrCreateEmail,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Continue'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: const [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('or'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _loading ? null : _signInAnonymous,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Continue as Admin (Anonymous)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Kids join with a code after role selection.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6E8FF)),
        ),
      );
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE6E8FF)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                color: Color(0x14000000),
                offset: Offset(0, 12),
              )
            ],
          ),
          child: const Icon(Icons.checklist_rounded, size: 40),
        ),
        const SizedBox(height: 10),
        const Text(
          'Donezy',
          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Cute tasks • happy kids • calm parents',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ValueProps extends StatelessWidget {
  const _ValueProps();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _Prop(
            icon: Icons.auto_awesome_rounded,
            title: 'Fun',
            subtitle: 'Kids actually care',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _Prop(
            icon: Icons.timelapse_rounded,
            title: 'Simple',
            subtitle: 'Fast to manage',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _Prop(
            icon: Icons.emoji_events_rounded,
            title: 'Rewards',
            subtitle: 'Points → prizes',
          ),
        ),
      ],
    );
  }
}

class _Prop extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Prop({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8FF)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CuteCard extends StatelessWidget {
  final Widget child;
  const _CuteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            color: Color(0x14000000),
            offset: Offset(0, 10),
          )
        ],
        border: Border.all(color: const Color(0xFFE6E8FF)),
      ),
      child: child,
    );
  }
}

class _CuteBackdrop extends StatelessWidget {
  const _CuteBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _BokehPainter(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFBFF),
                Color(0xFFF2F5FF),
                Color(0xFFFFF1F3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BokehPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    void circle(double x, double y, double r, Color c) {
      paint.color = c;
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, paint);
    }

    circle(0.15, 0.20, 60, const Color(0x22BFD0FF));
    circle(0.85, 0.18, 70, const Color(0x22FFC6D0));
    circle(0.80, 0.55, 85, const Color(0x18B8F7D4));
    circle(0.22, 0.72, 95, const Color(0x18FFD36A));
    circle(0.55, 0.85, 80, const Color(0x14C1B6FF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
