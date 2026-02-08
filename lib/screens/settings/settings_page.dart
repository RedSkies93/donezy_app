import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_shell.dart';
import '../../widgets/cute_toggle.dart';
import '../../widgets/pastel_card.dart';
import '../../widgets/bubble_button.dart';
import '../../widgets/ruled_paper_dialog.dart';
import '../../widgets/screen_background.dart';

import '../../core/asset_registry.dart';
import '../../core/constants.dart';
import '../../app/theme/app_colors.dart';

import '../../theme_mode/theme_store.dart';
import '../../theme_mode/theme_actions/set_theme_mode_action.dart';

import '../../actions/navigation/go_to_dashboard_action.dart';
import '../../actions/navigation/go_to_messages_action.dart';
import '../../actions/navigation/go_to_awards_action.dart';
import '../../actions/navigation/go_to_settings_action.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // Header notes:
  // routes used: via navigation actions only
  // actions called: SetThemeModeAction + navigation actions
  // services used: none (Phase 2 visuals only)
  // widgets composed: AppShell, CuteToggle, PastelCard, BubbleButton, ruled-paper dialog, ScreenBackground
  // theme/asset usage: AssetRegistry.bgSettings (optional), pastel gradients

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ThemeStore>();
    final setTheme = SetThemeModeAction();

    final goDash = GoToDashboardAction();
    final goMsg = GoToMessagesAction();
    final goAwards = GoToAwardsAction();
    final goSettings = GoToSettingsAction();

    return AppShell(
      title: 'Settings',
      currentIndex: 3,
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
        assetPath: AssetRegistry.bgSettings,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            PastelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Mode',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  CuteToggle<ThemeMode>(
                    value: store.mode,
                    options: const [
                      CuteToggleOption(
                          value: ThemeMode.system, label: 'System'),
                      CuteToggleOption(value: ThemeMode.light, label: 'Light'),
                      CuteToggleOption(value: ThemeMode.dark, label: 'Dark'),
                    ],
                    onChanged: (mode) {
                      setTheme.run(store: store, mode: mode);
                    },
                  ),
                  const SizedBox(height: 14),
                  BubbleButton(
                    gradient: AppColors.gBubbleWarm,
                    onPressed: () {
                      showRuledPaperDialog(
                        context: context,
                        title: 'Ruled Paper Preview',
                        child: const Text(
                          'This is the Phase 2 dialog shell.\nPhase 2.5 adds stickers, clouds, socks, sparkles!',
                        ),
                      );
                    },
                    child: const Text('Preview Cute Dialog'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
