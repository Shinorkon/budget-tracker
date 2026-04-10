import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Manages a Hive encryption key stored in the platform's secure keystore.
class HiveEncryptionService {
  static const _storageKey = 'hive_encryption_key';
  static const _storage = FlutterSecureStorage();

  /// Returns a 256-bit encryption key, creating one if it doesn't exist.
  static Future<Uint8List> getEncryptionKey() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null) {
      return base64Url.decode(existing);
    }

    final key = Hive.generateSecureKey();
    await _storage.write(
      key: _storageKey,
      value: base64Url.encode(key),
    );
    return Uint8List.fromList(key);
  }

  /// Returns a [HiveAesCipher] ready to be passed to `Hive.openBox()`.
  static Future<HiveAesCipher> getCipher() async {
    final key = await getEncryptionKey();
    return HiveAesCipher(key);
  }
}
