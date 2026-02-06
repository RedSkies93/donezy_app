import 'package:flutter/material.dart';

import '../../widgets/bubble_button.dart';
import '../../widgets/pastel_card.dart';
import '../../widgets/sparkle_overlay.dart';
import '../../widgets/corner_badge_overlay.dart';
import '../../widgets/screen_background.dart';

import '../../core/asset_registry.dart';
import '../../core/constants.dart';
import '../../app/theme/app_colors.dart';

import '../../actions/navigation/go_to_dashboard_action.dart';
import '../../actions/navigation/go_to_child_dashboard_action.dart';
import '../../actions/navigation/go_to_settings_action.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  // Header notes:
  // routes used: via navigation actions only
  // actions called: GoToDashboardAction, GoToChildDashboardAction, GoToSettingsAction
  // services used: none (Phase 2 visuals only)
  // widgets composed: ScreenBackground, PastelCard, BubbleButton
  // theme/asset usage: AssetRegistry.bgLogin (optional)

  @override
  Widget build(BuildContext context) {
    final goParent = GoToDashboardAction();
    final goChild = GoToChildDashboardAction();
    final goSettings = GoToSettingsAction();

    return Scaffold(
      appBar: AppBar(title: const Text('Donezy')),
      body: ScreenBackground(
        assetPath: AssetRegistry.bgLogin,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PastelCard(
                  overlay: const Stack(
                    children: [
                      SparkleOverlay(),
                      CornerBadgeOverlay(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Cute!',
                        alignment: Alignment.topRight,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Welcome to Donezy',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Chores + rewards, but make it cute ✨',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PastelCard(
                  overlay: const Stack(
                    children: [
                      SparkleOverlay(),
                      CornerBadgeOverlay(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Cute!',
                        alignment: Alignment.topRight,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BubbleButton(
                        onPressed: () => goParent.run(context),
                        gradient: AppColors.gBubbleWarm,
                        child: const Text('Enter as Parent'),
                      ),
                      const SizedBox(height: 12),
                      BubbleButton(
                        onPressed: () => goChild.run(context),
                        child: const Text('Enter as Child'),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => goSettings.run(context),
                        child: const Text('Settings'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



