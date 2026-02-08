import 'package:flutter/material.dart';

import '../../core/action_result.dart';
import '../../models/reward_model.dart';
import '../../services/rewards_service.dart';
import '../../widgets/ruled_paper_dialog.dart';
import '../../widgets/bubble_button.dart';

class ClaimRewardAction {
  Future<ActionResult<void>> run({
    required BuildContext context,
    required RewardsService service,
    required RewardModel reward,
  }) async {
    final ok = await showRuledPaperDialog<bool>(
      context: context,
      title: 'Claim Reward?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Claim:'),
          const SizedBox(height: 8),
          Text('"${reward.title}"',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Cost: ${reward.costPoints} points'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BubbleButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BubbleButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Claim'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true) {
      return const ActionResult.cancelled();
    }
    final success = await service.claimReward(reward);
    if (!success) {
      return const ActionResult.failure(
          'Not enough points or reward disabled.');
    }

    return const ActionResult.success();
  }
}
