import '../../models/reward_model.dart';

class MockRewards {
  static List<RewardModel> seed() => [
        const RewardModel(id: 'r1', title: 'Sticker Pack', costPoints: 50),
        const RewardModel(
            id: 'r2', title: 'Extra Screen Time', costPoints: 200),
        const RewardModel(
            id: 'r3',
            title: 'Ice Cream Trip',
            costPoints: 400,
            isEnabled: false),
      ];
}
