import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing authentication and encryption
/// Uses RSA key pairs for authentication and AES for message encryption
class SecurityService {
  static const String _keyPasswordHash = 'password_hash';
  static const String _keyPrivateKey = 'private_key';
  static const String _keyPublicKey = 'public_key';
  static const String _keyAesKey = 'aes_key';
  static const String _keyIsRoomCreator = 'is_room_creator';

  static final SecurityService instance = SecurityService._();
  SharedPreferences? _prefs;

  // In-memory keys for performance
  RSAPrivateKey? _privateKey;
  RSAPublicKey? _publicKey;
  Uint8List? _aesKey;

  SecurityService._();

  /// Initialize the security service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadKeys();
  }

  /// Load keys from storage into memory
  void _loadKeys() {
    if (_prefs == null) return;

    // Load private key
    final privateKeyPem = _prefs!.getString(_keyPrivateKey);
    if (privateKeyPem != null) {
      _privateKey = _parsePrivateKeyFromPem(privateKeyPem);
    }

    // Load public key
    final publicKeyPem = _prefs!.getString(_keyPublicKey);
    if (publicKeyPem != null) {
      _publicKey = _parsePublicKeyFromPem(publicKeyPem);
    }

    // Load AES key
    final aesKeyBase64 = _prefs!.getString(_keyAesKey);
    if (aesKeyBase64 != null) {
      _aesKey = base64Decode(aesKeyBase64);
    }
  }

  /// Hash a password using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Generate RSA key pair (2048-bit)
  Future<void> generateKeyPair() async {
    final keyGen = RSAKeyGenerator();
    final secureRandom = _getSecureRandom();

    keyGen.init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        secureRandom,
      ),
    );

    final pair = keyGen.generateKeyPair();
    _privateKey = pair.privateKey as RSAPrivateKey;
    _publicKey = pair.publicKey as RSAPublicKey;

    // Store keys
    await _prefs!.setString(
      _keyPrivateKey,
      _encodePrivateKeyToPem(_privateKey!),
    );
    await _prefs!.setString(_keyPublicKey, _encodePublicKeyToPem(_publicKey!));
  }

  /// Generate random AES-256 key for message encryption
  Future<void> generateAesKey() async {
    final secureRandom = Random.secure();
    _aesKey = Uint8List.fromList(
      List<int>.generate(32, (_) => secureRandom.nextInt(256)),
    );
    await _prefs!.setString(_keyAesKey, base64Encode(_aesKey!));
  }

  /// Get secure random for key generation
  SecureRandom _getSecureRandom() {
    final secureRandom = SecureRandom('Fortuna');
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(255));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// Encrypt data with RSA public key
  String encryptWithPublicKey(String plaintext, RSAPublicKey publicKey) {
    final encryptor = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final plainBytes = utf8.encode(plaintext);
    final encrypted = _processInBlocks(encryptor, plainBytes);
    return base64Encode(encrypted);
  }

  /// Encrypt data with RSA public key from PEM format
  String encryptWithPublicKeyPem(String plaintext, String publicKeyPem) {
    final publicKey = _parsePublicKeyFromPem(publicKeyPem);
    return encryptWithPublicKey(plaintext, publicKey);
  }

  /// Decrypt data with RSA private key
  String decryptWithPrivateKey(String ciphertext) {
    if (_privateKey == null) {
      throw Exception('No private key available');
    }

    final decryptor = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(_privateKey!));

    final cipherBytes = base64Decode(ciphertext);
    final decrypted = _processInBlocks(decryptor, cipherBytes);
    return utf8.decode(decrypted);
  }

  /// Process data in blocks for RSA encryption/decryption
  Uint8List _processInBlocks(AsymmetricBlockCipher cipher, Uint8List data) {
    final chunks = <Uint8List>[];
    final blockSize = cipher.inputBlockSize;

    for (int offset = 0; offset < data.length; offset += blockSize) {
      final end = (offset + blockSize < data.length)
          ? offset + blockSize
          : data.length;
      chunks.add(cipher.process(Uint8List.sublistView(data, offset, end)));
    }

    return Uint8List.fromList(chunks.expand((x) => x).toList());
  }

  /// Encrypt message with AES key
  String encryptMessage(String plaintext) {
    if (_aesKey == null) {
      throw Exception('No AES key available');
    }

    final key = KeyParameter(_aesKey!);
    final iv = _generateIV();

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(key, 128, iv, Uint8List(0)));

    final plainBytes = utf8.encode(plaintext);
    final encrypted = cipher.process(plainBytes);

    // Prepend IV to encrypted data
    final result = Uint8List(iv.length + encrypted.length);
    result.setRange(0, iv.length, iv);
    result.setRange(iv.length, result.length, encrypted);

    return base64Encode(result);
  }

  /// Decrypt message with AES key
  String decryptMessage(String ciphertext) {
    if (_aesKey == null) {
      throw Exception('No AES key available');
    }

    final data = base64Decode(ciphertext);
    final iv = data.sublist(0, 16);
    final encrypted = data.sublist(16);

    final key = KeyParameter(_aesKey!);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(key, 128, iv, Uint8List(0)));

    final decrypted = cipher.process(encrypted);
    return utf8.decode(decrypted);
  }

  /// Generate random IV for AES
  Uint8List _generateIV() {
    final secureRandom = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => secureRandom.nextInt(256)),
    );
  }

  /// Encode private key to PEM format
  String _encodePrivateKeyToPem(RSAPrivateKey key) {
    final asn1 = ASN1Sequence();
    asn1.add(ASN1Integer(BigInt.from(0))); // version
    asn1.add(ASN1Integer(key.modulus!));
    asn1.add(ASN1Integer(key.publicExponent!));
    asn1.add(ASN1Integer(key.privateExponent!));
    asn1.add(ASN1Integer(key.p!));
    asn1.add(ASN1Integer(key.q!));
    asn1.add(ASN1Integer(key.privateExponent! % (key.p! - BigInt.one)));
    asn1.add(ASN1Integer(key.privateExponent! % (key.q! - BigInt.one)));
    asn1.add(ASN1Integer(key.q!.modInverse(key.p!)));

    final bytes = asn1.encodedBytes;
    final base64String = base64Encode(bytes);
    return 'PRIVATE:$base64String';
  }

  /// Encode public key to PEM format
  String _encodePublicKeyToPem(RSAPublicKey key) {
    final asn1 = ASN1Sequence();
    asn1.add(ASN1Integer(key.modulus!));
    asn1.add(ASN1Integer(key.exponent!));

    final bytes = asn1.encodedBytes;
    final base64String = base64Encode(bytes);
    return 'PUBLIC:$base64String';
  }

  /// Parse private key from PEM format
  RSAPrivateKey _parsePrivateKeyFromPem(String pem) {
    final base64String = pem.replaceAll('PRIVATE:', '');
    final bytes = base64Decode(base64String);
    final asn1 = ASN1Parser(bytes).nextObject() as ASN1Sequence;

    return RSAPrivateKey(
      (asn1.elements[1] as ASN1Integer).valueAsBigInteger, // modulus
      (asn1.elements[3] as ASN1Integer).valueAsBigInteger, // privateExponent
      (asn1.elements[4] as ASN1Integer).valueAsBigInteger, // p
      (asn1.elements[5] as ASN1Integer).valueAsBigInteger, // q
    );
  }

  /// Parse public key from PEM format
  RSAPublicKey _parsePublicKeyFromPem(String pem) {
    final base64String = pem.replaceAll('PUBLIC:', '');
    final bytes = base64Decode(base64String);
    final asn1 = ASN1Parser(bytes).nextObject() as ASN1Sequence;

    return RSAPublicKey(
      (asn1.elements[0] as ASN1Integer).valueAsBigInteger, // modulus
      (asn1.elements[1] as ASN1Integer).valueAsBigInteger, // exponent
    );
  }

  /// Store AES key (received from another peer)
  Future<void> setAesKey(Uint8List key) async {
    _aesKey = key;
    await _prefs!.setString(_keyAesKey, base64Encode(key));
  }

  /// Store password hash
  Future<void> setPasswordHash(String hash) async {
    await _prefs!.setString(_keyPasswordHash, hash);
  }

  /// Set if this device is the room creator
  Future<void> setIsRoomCreator(bool isCreator) async {
    await _prefs!.setBool(_keyIsRoomCreator, isCreator);
  }

  /// Clear all security data
  Future<void> clearSecurityData() async {
    await _prefs!.remove(_keyPasswordHash);
    await _prefs!.remove(_keyPrivateKey);
    await _prefs!.remove(_keyPublicKey);
    await _prefs!.remove(_keyAesKey);
    await _prefs!.remove(_keyIsRoomCreator);

    _privateKey = null;
    _publicKey = null;
    _aesKey = null;
  }

  // Getters
  String? get passwordHash => _prefs?.getString(_keyPasswordHash);
  bool get hasPassword => passwordHash != null && passwordHash!.isNotEmpty;
  bool get hasKeyPair => _privateKey != null && _publicKey != null;
  bool get hasAesKey => _aesKey != null;
  bool get isAuthenticated => hasPassword && hasKeyPair && hasAesKey;
  bool get isRoomCreator => _prefs?.getBool(_keyIsRoomCreator) ?? false;

  String? get publicKeyPem =>
      _publicKey != null ? _encodePublicKeyToPem(_publicKey!) : null;
  RSAPublicKey? get publicKey => _publicKey;

  /// Get AES key as base64 string for network transmission
  String? get aesKeyBase64 => _aesKey != null ? base64Encode(_aesKey!) : null;
}
