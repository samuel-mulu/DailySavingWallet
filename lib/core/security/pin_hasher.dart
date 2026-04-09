import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PinHasher {
  String generateSalt({int length = 16}) {
    final r = Random.secure();
    final bytes = List<int>.generate(length, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String hashPin({required String pin, required String salt}) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
