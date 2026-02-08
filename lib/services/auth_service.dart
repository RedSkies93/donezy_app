import 'session_store.dart';

class AuthService {
  final SessionStore session;

  AuthService(this.session);

  Future<void> signInMock({required String userId}) async {
    session.userId = userId;
  }

  Future<void> signOut() async {
    session.userId = '';
  }
}
