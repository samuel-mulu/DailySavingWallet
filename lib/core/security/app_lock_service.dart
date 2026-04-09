import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_hasher.dart';

class AppLockService {
  static const _kPinSalt = 'pin_salt';
  static const _kPinHash = 'pin_hash';
  static const _kBioEnabled = 'bio_enabled';

  final FlutterSecureStorage _storage;
  final PinHasher _hasher;

  AppLockService({FlutterSecureStorage? storage, PinHasher? hasher})
    : _storage = storage ?? const FlutterSecureStorage(),
      _hasher = hasher ?? PinHasher();

  Future<bool> isPinSet() async {
    final hash = await _storage.read(key: _kPinHash);
    final salt = await _storage.read(key: _kPinSalt);
    return (hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty);
  }

  Future<void> setPin(String pin, {bool enableBiometric = true}) async {
    final salt = _hasher.generateSalt();
    final hash = _hasher.hashPin(pin: pin, salt: salt);
    await _storage.write(key: _kPinSalt, value: salt);
    await _storage.write(key: _kPinHash, value: hash);
    await _storage.write(key: _kBioEnabled, value: enableBiometric ? '1' : '0');
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kPinSalt);
    final savedHash = await _storage.read(key: _kPinHash);
    if (salt == null || savedHash == null) return false;
    final hash = _hasher.hashPin(pin: pin, salt: salt);
    return hash == savedHash;
  }

  Future<bool> biometricEnabled() async {
    final v = await _storage.read(key: _kBioEnabled);
    return v == null ? true : v == '1';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _kBioEnabled, value: enabled ? '1' : '0');
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _kPinSalt);
    await _storage.delete(key: _kPinHash);
  }
}
