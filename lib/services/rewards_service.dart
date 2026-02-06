import '../models/reward_model.dart';
import 'mock_data/mock_rewards.dart';
import 'child_store.dart';
import 'reward_claim_store.dart';

class RewardsService {
  final ChildStore childStore;
  final RewardClaimStore claimStore;

  RewardsService(this.childStore, this.claimStore);

  Future<List<RewardModel>> listRewards() async => MockRewards.seed();

  Future<bool> claimReward(RewardModel reward) async {
    if (!reward.isEnabled) return false;
    if (!childStore.canAfford(reward.costPoints)) return false;

    childStore.spend(reward.costPoints);

    claimStore.addClaim(
      RewardClaimEntry(
        id: 'c_${DateTime.now().microsecondsSinceEpoch}',
        rewardTitle: reward.title,
        costPoints: reward.costPoints,
        claimedAt: DateTime.now(),
      ),
    );

    return true;
  }
}
