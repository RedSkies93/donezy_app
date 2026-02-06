import 'package:flutter/foundation.dart';

class ChildStore extends ChangeNotifier {
  int _points = 120;

  int get points => _points;

  void setPoints(int v) {
    _points = v < 0 ? 0 : v;
    notifyListeners();
  }

  bool canAfford(int cost) => _points >= cost;

  void spend(int cost) {
    if (cost <= 0) return;
    _points -= cost;
    if (_points < 0) _points = 0;
    notifyListeners();
  }

  void earn(int amount) {
    if (amount <= 0) return;
    _points += amount;
    notifyListeners();
  }
}
