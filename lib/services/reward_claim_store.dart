import 'package:flutter/foundation.dart';

class RewardClaimEntry {
  final String id;
  final String rewardTitle;
  final int costPoints;
  final DateTime claimedAt;

  RewardClaimEntry({
    required this.id,
    required this.rewardTitle,
    required this.costPoints,
    required this.claimedAt,
  });
}

class RewardClaimStore extends ChangeNotifier {
  List<RewardClaimEntry> _claims = const [];

  List<RewardClaimEntry> get claims => _claims;

  void addClaim(RewardClaimEntry entry) {
    _claims = List.unmodifiable([entry, ..._claims]);
    notifyListeners();
  }

  void clear() {
    _claims = const [];
    notifyListeners();
  }
}
