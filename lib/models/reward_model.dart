class RewardModel {
  final String id;
  final String title;
  final int costPoints;
  final bool isEnabled;

  const RewardModel({
    required this.id,
    required this.title,
    required this.costPoints,
    this.isEnabled = true,
  });
}
