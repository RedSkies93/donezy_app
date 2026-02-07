import 'session_store.dart';
import 'auth_service.dart';
import 'task_service.dart';
import 'chat_service.dart';
import 'rewards_service.dart';
import 'task_store.dart';
import 'child_store.dart';
import 'chat_store.dart';
import 'reward_claim_store.dart';
import 'firestore_service.dart';
import '../app/app_config.dart';

class ServiceRegistry {
  final AppConfig config;

  late final SessionStore session;
  late final AuthService auth;

  late final TaskStore taskStore;
  late final ChildStore childStore;

  late final FirestoreService firestore;
  late final TaskService tasks;

  late final ChatStore chatStore;
  late final ChatService chat;

  late final RewardClaimStore rewardClaimStore;
  late final RewardsService rewards;

  ServiceRegistry({required this.config}) {
    session = SessionStore();
    auth = AuthService(session);

    taskStore = TaskStore();
    childStore = ChildStore();

    firestore = FirestoreService();

    tasks = TaskService(
      taskStore,
      childStore,
      config: config,
      session: session,
      firestore: firestore,
    );

    chatStore = ChatStore();
    chat = ChatService(chatStore);

    rewardClaimStore = RewardClaimStore();
    rewards = RewardsService(childStore, rewardClaimStore);
  }
}
