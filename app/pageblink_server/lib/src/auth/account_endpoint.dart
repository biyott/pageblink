import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../demo/demo_user.dart';
import '../generated/protocol.dart';
import '../services/acl.dart';

/// The signed-in user's own account line. The standard
/// `serverpod_auth_core.userProfileInfo.get` is not used: demo accounts have
/// no profile (it would throw an error that is not serializable, a 500).
class AccountEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Email (null for demo / unknown) and demo flag of the caller. The email is
  /// not logged.
  Future<AccountInfo> me(Session session) async {
    final userId = Acl.requireUser(session);
    if (DemoUser.isDemo(userId)) return AccountInfo(isDemo: true);
    final account = await EmailAccount.db.findFirstRow(
      session,
      where: (t) => t.authUserId.equals(userId),
    );
    return AccountInfo(email: account?.email, isDemo: false);
  }
}
