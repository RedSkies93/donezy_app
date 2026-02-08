import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_shell.dart';
import '../../widgets/pastel_card.dart';
import '../../widgets/screen_background.dart';
import '../../widgets/points_pill.dart';
import '../../widgets/bubble_button.dart';

import '../../core/asset_registry.dart';
import '../../core/constants.dart';

import '../../models/reward_model.dart';
import '../../services/rewards_service.dart';
import '../../services/child_store.dart';
import '../../services/reward_claim_store.dart';
import '../../actions/awards/claim_reward_action.dart';

import '../../actions/navigation/go_to_dashboard_action.dart';
import '../../actions/navigation/go_to_messages_action.dart';
import '../../actions/navigation/go_to_awards_action.dart';
import '../../actions/navigation/go_to_settings_action.dart';

class AwardsPage extends StatelessWidget {
  const AwardsPage({super.key});

  // Header notes:
  // routes used: via navigation actions only
  // actions called: ClaimRewardAction + navigation actions
  // services used: RewardsService (mock), ChildStore (points)
  // widgets composed: AppShell, ScreenBackground, PastelCard, PointsPill, BubbleButton
  // theme/asset usage: AssetRegistry.bgAwards (optional)

  @override
  Widget build(BuildContext context) {
    final rewards = context.read<RewardsService>();
    final points = context.watch<ChildStore>().points;
    final claims = context.watch<RewardClaimStore>().claims;
    final claim = ClaimRewardAction();

    final goDash = GoToDashboardAction();
    final goMsg = GoToMessagesAction();
    final goAwards = GoToAwardsAction();
    final goSettings = GoToSettingsAction();

    return AppShell(
      title: 'Awards',
      currentIndex: 2,
      onNavTap: (i) {
        switch (i) {
          case 0:
            goDash.run(context);
            break;
          case 1:
            goMsg.run(context);
            break;
          case 2:
            goAwards.run(context);
            break;
          case 3:
            goSettings.run(context);
            break;
        }
      },
      body: ScreenBackground(
        assetPath: AssetRegistry.bgAwards,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            PastelCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rewards Store \u{1F381}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  PointsPill(points: points),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            PastelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Claims \u{1F9FE}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  if (claims.isEmpty)
                    const Text('No claims yet. Claim a reward to see it here!')
                  else
                    ...claims.take(5).map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text(c.rewardTitle)),
                                Text('-'),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            FutureBuilder<List<RewardModel>>(
              future: rewards.listRewards(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const PastelCard(child: Text('Loading rewards...'));
                }
                final items = snap.data!;
                return Column(
                  children: [
                    for (final r in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PastelCard(
                          child: Row(
                            children: [
                              Icon(r.isEnabled
                                  ? Icons.card_giftcard_rounded
                                  : Icons.block_rounded),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    Text('${r.costPoints} pts'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 110,
                                child: BubbleButton(
                                  onPressed:
                                      (!r.isEnabled || points < r.costPoints)
                                          ? null
                                          : () => claim.run(
                                              context: context,
                                              service: rewards,
                                              reward: r),
                                  child: const Text('Claim'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
