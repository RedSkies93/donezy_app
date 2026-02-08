import 'package:flutter/foundation.dart';

import '../models/child_model.dart';

class SessionStore extends ChangeNotifier {
  String userId = '';
  bool isParentMode = true;

  /// Phase 2: single-family demo scope (visible data immediately)
  /// Later: replace with real family-code/linking flow.
  String familyId = 'demo_family';

  // Phase J: demo children + selection (parent can flip views)
  // Later: replace with Firestore-backed children store.
  List<ChildModel> children = const <ChildModel>[
    ChildModel(id: 'child_1', name: 'Child 1'),
    ChildModel(id: 'child_2', name: 'Child 2'),
  ];

  String? selectedChildId;

  void setSelectedChildId(String? id) {
    selectedChildId = (id != null && id.isEmpty) ? null : id;
    notifyListeners();
  }

  void setUserId(String id) {
    userId = id;
    notifyListeners();
  }

  void setFamilyId(String id) {
    familyId = id.isEmpty ? 'demo_family' : id;
    notifyListeners();
  }
}
