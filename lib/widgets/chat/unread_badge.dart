import 'package:flutter/material.dart';

class UnreadBadge extends StatelessWidget {
  final int count;
  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) =>
      count <= 0 ? const SizedBox.shrink() : Badge(label: Text('$count'));
}
