import '../../../core/logging/app_logger.dart';
import '../../../data/api/auth_api.dart';

class CustomerLinkResolver {
  final AuthApi _authApi;

  CustomerLinkResolver({AuthApi? authApi})
    : _authApi = authApi ?? AuthApi();

  Future<String?> resolveCustomerId(String uid) async {
    try {
      final me = await _authApi.fetchMe();
      if (me.userId != uid) {
        return null;
      }
      return me.customerId;
    } catch (error, stackTrace) {
      AppLogger.error(
        '[CustomerLinkResolver] backend auth/me failed',
        error,
        stackTrace,
      );
      return null;
    }
  }
}
