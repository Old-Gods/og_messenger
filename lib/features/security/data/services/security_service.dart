import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing room security, encryption, and password validation
class SecurityService {
  static const String _keyPasswordHash = 'room_password_hash';
  static const String _keyEncryptionKey = 'room_encryption_key';
  static const String _keyEncryptedKey =
      'room_encrypted_key'; // Encrypted version for broadcasting
  static const String _keyIsRoomCreator = 'is_room_creator';
  static const String _keyRoomCreatedTimestamp = 'room_created_timestamp';
  static const String _keyFailedAttempts = 'failed_attempts';
  static const String _keyLockoutUntil = 'lockout_until';

  static final SecurityService instance = SecurityService._();
  SharedPreferences? _prefs;
  encrypt_pkg.Key? _encryptionKey;

  SecurityService._();

  /// Initialize the security service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadEncryptionKey();
  }

  /// Load encryption key from storage
  void _loadEncryptionKey() {
    final keyBase64 = _prefs?.getString(_keyEncryptionKey);
    if (keyBase64 != null && keyBase64.isNotEmpty) {
      _encryptionKey = encrypt_pkg.Key.fromBase64(keyBase64);
    }
  }

  /// Hash a password using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Derive an encryption key from a password using PBKDF2
  /// Used to encrypt/decrypt the AES key with the password
  encrypt_pkg.Key deriveKeyFromPassword(String password, String salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(
      Pbkdf2Parameters(
        utf8.encode(salt),
        10000, // iterations
        32, // key length (256 bits)
      ),
    );
    final key = derivator.process(utf8.encode(password));
    return encrypt_pkg.Key(key);
  }

  /// Generate a random AES-256 encryption key
  encrypt_pkg.Key generateRandomKey() {
    final secureRandom = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => secureRandom.nextInt(256));
    return encrypt_pkg.Key(Uint8List.fromList(keyBytes));
  }

  /// Encrypt the AES key with a password-derived key
  String encryptKeyWithPassword(
    encrypt_pkg.Key aesKey,
    String password,
    String salt,
  ) {
    print('🔒 Encrypting key...');
    print('   Password: $password');
    print('   Salt: $salt');

    final passwordKey = deriveKeyFromPassword(password, salt);
    print('   Derived key from password: ${passwordKey.base64}');

    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(passwordKey, mode: encrypt_pkg.AESMode.gcm),
    );
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(aesKey.base64, iv: iv);

    final result = '${iv.base64}:${encrypted.base64}';
    print('   Result: $result');
    print('   Result length: ${result.length}');

    return result;
  }

  /// Decrypt the AES key with a password-derived key
  encrypt_pkg.Key? decryptKeyWithPassword(
    String encryptedKey,
    String password,
    String salt,
  ) {
    try {
      print('🔓 Decrypting key...');
      print('   Encrypted key: $encryptedKey');
      print('   Password: $password');
      print('   Salt: $salt');

      final parts = encryptedKey.split(':');
      if (parts.length != 2) {
        print('❌ Invalid format: expected IV:data');
        return null;
      }

      print('   IV part: ${parts[0]}');
      print('   Encrypted part: ${parts[1]}');
      print('   Encrypted part length: ${parts[1].length}');

      final iv = encrypt_pkg.IV.fromBase64(parts[0]);
      final encrypted = encrypt_pkg.Encrypted.fromBase64(parts[1]);
      final passwordKey = deriveKeyFromPassword(password, salt);

      print('   Derived key from password: ${passwordKey.base64}');

      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(passwordKey, mode: encrypt_pkg.AESMode.gcm),
      );
      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      print('   Decrypted value: $decrypted');
      print('   Decrypted length: ${decrypted.length}');

      return encrypt_pkg.Key.fromBase64(decrypted);
    } catch (e, stackTrace) {
      print('❌ Failed to decrypt key: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Encrypt a message using the room's AES key
  String encryptMessage(String plaintext) {
    if (_encryptionKey == null) {
      throw Exception('No encryption key set');
    }

    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(_encryptionKey!, mode: encrypt_pkg.AESMode.gcm),
    );
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt a message using the room's AES key
  String decryptMessage(String ciphertext) {
    if (_encryptionKey == null) {
      throw Exception('No encryption key set');
    }

    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2) {
        throw Exception('Invalid ciphertext format');
      }

      final iv = encrypt_pkg.IV.fromBase64(parts[0]);
      final encrypted = encrypt_pkg.Encrypted.fromBase64(parts[1]);
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(_encryptionKey!, mode: encrypt_pkg.AESMode.gcm),
      );
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('❌ Failed to decrypt message: $e');
      // Return original ciphertext to prevent crashes, mark as error
      return '[Encrypted - Unable to decrypt]';
    }
  }

  /// Get current password hash
  String? get passwordHash {
    return _prefs?.getString(_keyPasswordHash);
  }

  /// Set password hash
  Future<bool> setPasswordHash(String hash) async {
    if (_prefs == null) return false;
    return await _prefs!.setString(_keyPasswordHash, hash);
  }

  /// Set encryption key
  Future<bool> setEncryptionKey(encrypt_pkg.Key key) async {
    if (_prefs == null) return false;
    _encryptionKey = key;
    return await _prefs!.setString(_keyEncryptionKey, key.base64);
  }

  /// Get encryption key
  encrypt_pkg.Key? get encryptionKey => _encryptionKey;

  /// Get encrypted key (for broadcasting)
  String? get encryptedKey {
    return _prefs?.getString(_keyEncryptedKey);
  }

  /// Set encrypted key (for broadcasting)
  Future<bool> setEncryptedKey(String encryptedKey) async {
    if (_prefs == null) return false;
    return await _prefs!.setString(_keyEncryptedKey, encryptedKey);
  }

  /// Check if password is set
  bool get hasPassword {
    return passwordHash != null && passwordHash!.isNotEmpty;
  }

  /// Verify password
  bool verifyPassword(String password) {
    final hash = hashPassword(password);
    return hash == passwordHash;
  }

  /// Get if this device is the room creator
  bool get isRoomCreator {
    return _prefs?.getBool(_keyIsRoomCreator) ?? false;
  }

  /// Set if this device is the room creator
  Future<bool> setIsRoomCreator(bool value) async {
    if (_prefs == null) return false;
    return await _prefs!.setBool(_keyIsRoomCreator, value);
  }

  /// Get room created timestamp
  int? get roomCreatedTimestamp {
    return _prefs?.getInt(_keyRoomCreatedTimestamp);
  }

  /// Set room created timestamp
  Future<bool> setRoomCreatedTimestamp(int timestamp) async {
    if (_prefs == null) return false;
    return await _prefs!.setInt(_keyRoomCreatedTimestamp, timestamp);
  }

  /// Get failed password attempts
  int get failedAttempts {
    return _prefs?.getInt(_keyFailedAttempts) ?? 0;
  }

  /// Increment failed attempts
  Future<void> incrementFailedAttempts() async {
    if (_prefs == null) return;
    final current = failedAttempts;
    await _prefs!.setInt(_keyFailedAttempts, current + 1);

    // Lock out after 5 failed attempts
    if (current + 1 >= 5) {
      final lockoutUntil = DateTime.now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch;
      await _prefs!.setInt(_keyLockoutUntil, lockoutUntil);
    }
  }

  /// Reset failed attempts
  Future<void> resetFailedAttempts() async {
    if (_prefs == null) return;
    await _prefs!.remove(_keyFailedAttempts);
    await _prefs!.remove(_keyLockoutUntil);
  }

  /// Check if user is locked out
  bool get isLockedOut {
    final lockoutUntil = _prefs?.getInt(_keyLockoutUntil);
    if (lockoutUntil == null) return false;
    return DateTime.now().millisecondsSinceEpoch < lockoutUntil;
  }

  /// Get remaining lockout time in seconds
  int get lockoutRemainingSeconds {
    final lockoutUntil = _prefs?.getInt(_keyLockoutUntil);
    if (lockoutUntil == null) return 0;
    final remaining = lockoutUntil - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  /// Clear all security data
  Future<void> clearSecurityData() async {
    if (_prefs == null) return;
    await _prefs!.remove(_keyPasswordHash);
    await _prefs!.remove(_keyEncryptionKey);
    await _prefs!.remove(_keyEncryptedKey);
    await _prefs!.remove(_keyIsRoomCreator);
    await _prefs!.remove(_keyRoomCreatedTimestamp);
    await _prefs!.remove(_keyFailedAttempts);
    await _prefs!.remove(_keyLockoutUntil);
    _encryptionKey = null;
  }
}
