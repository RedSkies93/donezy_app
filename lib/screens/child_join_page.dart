import 'package:flutter/material.dart';
import '../services/session_store.dart';
import '../services/code_join_service.dart';
import 'child_dashboard_page.dart';

class ChildJoinPage extends StatefulWidget {
  const ChildJoinPage({super.key});
  static const routeName = '/child-join';

  @override
  State<ChildJoinPage> createState() => _ChildJoinPageState();
}

class _ChildJoinPageState extends State<ChildJoinPage> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await CodeJoinService.joinWithCode(_codeCtrl.text);
      if (!result.success) {
        setState(() => _error = result.message);
        return;
      }

      await SessionStore.setChildLink(
        parentUid: result.parentUid!,
        childId: result.childId!,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChildDashboardPage(
            parentUid: result.parentUid!,
            childId: result.childId!,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text('Join Household'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'Enter your code',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text('Ask your parent for your KID-XXXXXX code.'),
            const SizedBox(height: 16),

            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Code',
                hintText: 'KID-ABC123',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : _join,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
