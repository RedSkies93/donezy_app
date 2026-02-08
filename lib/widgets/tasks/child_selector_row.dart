import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/session_store.dart';

class ChildSelectorRow extends StatelessWidget {
  const ChildSelectorRow({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();

    final children = session.children;
    if (children.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in children)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.name),
                selected: session.selectedChildId == c.id,
                onSelected: (_) => session.setSelectedChildId(c.id),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: session.selectedChildId == null,
              onSelected: (_) => session.setSelectedChildId(null),
            ),
          ),
        ],
      ),
    );
  }
}
