import 'package:flutter_test/flutter_test.dart';
import 'package:og_messenger/features/security/data/services/security_service.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group('SecurityService', () {
    late SecurityService securityService;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      securityService = SecurityService.instance;
    });

    group('initialization', () {
      test('initializes successfully', () async {
        await expectLater(securityService.initialize(), completes);
      });
    });

    group('password hashing', () {
      test('hashes password correctly using SHA-256', () async {
        await securityService.initialize();

        final password = 'testPassword123';
        final hash1 = securityService.hashPassword(password);
        final hash2 = securityService.hashPassword(password);

        expect(hash1, isNotEmpty);
        expect(hash1, hash2); // Same password should produce same hash
        expect(hash1.length, 64); // SHA-256 produces 64 hex characters
      });

      test('different passwords produce different hashes', () async {
        await securityService.initialize();

        final hash1 = securityService.hashPassword('password1');
        final hash2 = securityService.hashPassword('password2');

        expect(hash1, isNot(equals(hash2)));
      });

      test('empty password produces valid hash', () async {
        await securityService.initialize();

        final hash = securityService.hashPassword('');
        expect(hash, isNotEmpty);
        expect(hash.length, 64);
      });
    });

    group('password storage and verification', () {
      test('stores and verifies password correctly', () async {
        await securityService.initialize();

        final password = 'mySecurePassword123';
        await securityService.setPassword(password);

        expect(securityService.hasPassword(), true);
        expect(securityService.verifyPassword(password), true);
        expect(securityService.verifyPassword('wrongPassword'), false);
      });

      test('hasPassword returns false when no password is set', () async {
        await securityService.initialize();

        expect(securityService.hasPassword(), false);
      });
    });

    group('RSA key generation', () {
      test('generates RSA key pair successfully', () async {
        await securityService.initialize();

        await securityService.generateKeyPair();

        expect(securityService.hasKeyPair(), true);
        expect(securityService.getPublicKeyPem(), isNotNull);
        expect(securityService.getPublicKeyPem(), contains('BEGIN PUBLIC KEY'));
        expect(securityService.getPublicKeyPem(), contains('END PUBLIC KEY'));
      });

      test('hasKeyPair returns false when no keys generated', () async {
        await securityService.initialize();

        expect(securityService.hasKeyPair(), false);
      });

      test('generated public key is different each time', () async {
        await securityService.initialize();

        await securityService.generateKeyPair();
        final publicKey1 = securityService.getPublicKeyPem();

        // Clear and regenerate
        TestHelpers.setupMockSharedPreferences();
        final newService = SecurityService.instance;
        await newService.initialize();
        await newService.generateKeyPair();
        final publicKey2 = newService.getPublicKeyPem();

        expect(publicKey1, isNot(equals(publicKey2)));
      });
    });

    group('AES key generation', () {
      test('generates AES key successfully', () async {
        await securityService.initialize();

        await securityService.generateAesKey();

        expect(securityService.hasAesKey(), true);
      });

      test('hasAesKey returns false when no AES key generated', () async {
        await securityService.initialize();

        expect(securityService.hasAesKey(), false);
      });

      test('generated AES key is different each time', () async {
        await securityService.initialize();

        await securityService.generateAesKey();
        final aesKey1 = securityService.getAesKey();

        // Clear and regenerate
        TestHelpers.setupMockSharedPreferences();
        final newService = SecurityService.instance;
        await newService.initialize();
        await newService.generateAesKey();
        final aesKey2 = newService.getAesKey();

        expect(aesKey1, isNot(equals(aesKey2)));
      });
    });

    group('message encryption and decryption', () {
      test('encrypts and decrypts message successfully', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final originalMessage = 'Hello, this is a secret message!';
        final encrypted = securityService.encryptMessage(originalMessage);
        final decrypted = securityService.decryptMessage(encrypted);

        expect(encrypted, isNot(equals(originalMessage)));
        expect(decrypted, equals(originalMessage));
      });

      test('encrypted message is different each time (due to IV)', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final message = 'Same message';
        final encrypted1 = securityService.encryptMessage(message);
        final encrypted2 = securityService.encryptMessage(message);

        expect(encrypted1, isNot(equals(encrypted2))); // Different IVs
        expect(securityService.decryptMessage(encrypted1), equals(message));
        expect(securityService.decryptMessage(encrypted2), equals(message));
      });

      test('handles empty message encryption', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final encrypted = securityService.encryptMessage('');
        final decrypted = securityService.decryptMessage(encrypted);

        expect(decrypted, equals(''));
      });

      test('handles long message encryption', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final longMessage = 'A' * 10000;
        final encrypted = securityService.encryptMessage(longMessage);
        final decrypted = securityService.decryptMessage(encrypted);

        expect(decrypted, equals(longMessage));
      });
    });

    group('room creator flag', () {
      test('sets and retrieves room creator flag', () async {
        await securityService.initialize();

        await securityService.setIsRoomCreator(true);
        expect(securityService.isRoomCreator(), true);

        await securityService.setIsRoomCreator(false);
        expect(securityService.isRoomCreator(), false);
      });

      test('defaults to false when not set', () async {
        await securityService.initialize();

        expect(securityService.isRoomCreator(), false);
      });
    });

    group('RSA signature', () {
      test('signs and verifies data successfully', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        final data = 'Important data to sign';
        final signature = securityService.signData(data);
        final publicKeyPem = securityService.getPublicKeyPem()!;
        final isValid = securityService.verifySignature(
          data,
          signature,
          publicKeyPem,
        );

        expect(signature, isNotEmpty);
        expect(isValid, true);
      });

      test('signature verification fails with wrong data', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        final data = 'Original data';
        final signature = securityService.signData(data);
        final publicKeyPem = securityService.getPublicKeyPem()!;

        final isValid = securityService.verifySignature(
          'Modified data',
          signature,
          publicKeyPem,
        );

        expect(isValid, false);
      });

      test('signature verification fails with wrong public key', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        final data = 'Data to sign';
        final signature = securityService.signData(data);

        // Generate different key pair
        TestHelpers.setupMockSharedPreferences();
        final newService = SecurityService.instance;
        await newService.initialize();
        await newService.generateKeyPair();
        final differentPublicKey = newService.getPublicKeyPem()!;

        final isValid = securityService.verifySignature(
          data,
          signature,
          differentPublicKey,
        );

        expect(isValid, false);
      });
    });
  });
}
