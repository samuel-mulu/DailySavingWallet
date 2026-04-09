import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_client.dart';
import '../../../data/api/auth_api.dart';
import '../../../data/users/user_model.dart';
import '../services/auth_client.dart';

final backendSessionStoreProvider = Provider<BackendSessionStore>(
  (ref) => const BackendSessionStore(),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(sessionStore: ref.watch(backendSessionStoreProvider)),
);

final authClientProvider = Provider<AuthClient>(
  (ref) => NodeAuthClient(authApi: ref.watch(authApiProvider)),
);

final authUidProvider = StreamProvider<String?>(
  (ref) => ref.watch(authClientProvider).authUidChanges(),
);

final appUserProfileProvider = FutureProvider.family<AppUser, String>(
  (ref, uid) async {
    final me = await ref.watch(authApiProvider).fetchMe();
    if (me.userId != uid) {
      throw StateError('Session does not match requested user');
    }
    return AppUser.fromBackendMe(me);
  },
);

/// First segment of account email for header chips (falls back to "User").
final accountDisplayLabelProvider = FutureProvider<String>((ref) async {
  final me = await ref.watch(authApiProvider).fetchMe();
  final email = me.email.trim();
  if (email.isEmpty) return 'User';
  final at = email.split('@');
  return at.isNotEmpty ? at.first : 'User';
});
