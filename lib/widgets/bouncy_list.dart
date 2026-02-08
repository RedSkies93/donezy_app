import 'package:flutter/material.dart';

class BouncyList extends StatelessWidget {
  final List<Widget> children;
  const BouncyList({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    // Phase 1: simple wrapper. Phase 2 adds bounce physics feel (no behavior risk now).
    return ListView(children: children);
  }
}
