import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import '../app/theme/app_text.dart';

import 'app_config.dart';
import '../core/constants.dart';

import '../theme_mode/theme_store.dart';
import '../services/service_registry.dart';
import '../services/session_store.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';
import '../services/task_store.dart';
import '../services/child_store.dart';
import '../services/chat_store.dart';
import '../services/reward_claim_store.dart';
import '../services/chat_service.dart';
import '../services/rewards_service.dart';

class DonezyApp extends StatelessWidget {
  const DonezyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const config = AppConfig.mockFirst;

    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: config),

        Provider<ServiceRegistry>(
          create: (_) => ServiceRegistry(config: config),
        ),

        // Expose services/stores (keeps UI clean later; actions can read from Provider)
        ProxyProvider<ServiceRegistry, SessionStore>(
          update: (_, reg, __) => reg.session,
        ),
        ProxyProvider<ServiceRegistry, AuthService>(
          update: (_, reg, __) => reg.auth,
        ),
        ProxyProvider<ServiceRegistry, TaskService>(
          update: (_, reg, __) => reg.tasks,
        ),
        ChangeNotifierProxyProvider<ServiceRegistry, TaskStore>(
          create: (_) => TaskStore(),
          update: (_, reg, __) => reg.taskStore,
        ),
        ChangeNotifierProxyProvider<ServiceRegistry, ChildStore>(
          create: (_) => ChildStore(),
          update: (_, reg, __) => reg.childStore,
        ),
        ChangeNotifierProxyProvider<ServiceRegistry, ChatStore>(
          create: (_) => ChatStore(),
          update: (_, reg, __) => reg.chatStore,
        ),
        ChangeNotifierProxyProvider<ServiceRegistry, RewardClaimStore>(
          create: (_) => RewardClaimStore(),
          update: (_, reg, __) => reg.rewardClaimStore,
        ),
        ProxyProvider<ServiceRegistry, ChatService>(
          update: (_, reg, __) => reg.chat,
        ),
        ProxyProvider<ServiceRegistry, RewardsService>(
          update: (_, reg, __) => reg.rewards,
        ),

        ChangeNotifierProvider(
          create: (_) => ThemeStore(),
        ),
      ],
      child: Consumer<ThemeStore>(
        builder: (context, themeStore, _) {
          return MaterialApp(
            title: AppText.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeStore.mode,
            initialRoute: AppRoutes.login,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}











