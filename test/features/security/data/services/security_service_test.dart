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

    group('message encryption (AES)', () {
      test('encrypts message successfully', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final plaintext = 'Hello, World!';
        final ciphertext = securityService.encryptMessage(plaintext);

        expect(ciphertext, isNotEmpty);
        expect(ciphertext, isNot(equals(plaintext)));
      });

      test('decrypts message successfully', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final plaintext = 'Hello, World!';
        final ciphertext = securityService.encryptMessage(plaintext);
        final decrypted = securityService.decryptMessage(ciphertext);

        expect(decrypted, equals(plaintext));
      });

      test('encrypted messages are different even for same input', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final plaintext = 'Test message';
        final ciphertext1 = securityService.encryptMessage(plaintext);
        final ciphertext2 = securityService.encryptMessage(plaintext);

        // Should be different due to IV
        expect(ciphertext1, isNot(equals(ciphertext2)));

        // But both should decrypt to same plaintext
        expect(securityService.decryptMessage(ciphertext1), equals(plaintext));
        expect(securityService.decryptMessage(ciphertext2), equals(plaintext));
      });

      test('encrypts and decrypts long messages', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final longMessage = 'A' * 1000;
        final ciphertext = securityService.encryptMessage(longMessage);
        final decrypted = securityService.decryptMessage(ciphertext);

        expect(decrypted, equals(longMessage));
      });

      test('encrypts and decrypts empty message', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final plaintext = '';
        final ciphertext = securityService.encryptMessage(plaintext);
        final decrypted = securityService.decryptMessage(ciphertext);

        expect(decrypted, equals(plaintext));
      });

      test('encrypts and decrypts special characters', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final plaintext = '!@#\$%^&*()_+-=[]{}|;:\'",.<>?/\\`~';
        final ciphertext = securityService.encryptMessage(plaintext);
        final decrypted = securityService.decryptMessage(ciphertext);

        expect(decrypted, equals(plaintext));
      });

      test('encrypts and decrypts unicode characters', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        final plaintext = '你好世界 🌍 مرحبا 😀';
        final ciphertext = securityService.encryptMessage(plaintext);
        final decrypted = securityService.decryptMessage(ciphertext);

        expect(decrypted, equals(plaintext));
      });
    });

    group('RSA encryption', () {
      test('encrypts with public key successfully', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        final publicKey = securityService.publicKey!;
        final plaintext = 'Test message';

        final ciphertext = securityService.encryptWithPublicKey(
          plaintext,
          publicKey,
        );

        expect(ciphertext, isNotEmpty);
        expect(ciphertext, isNot(equals(plaintext)));
      });

      test('decrypts RSA-encrypted message', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        final publicKey = securityService.publicKey!;
        final plaintext = 'Test message';

        final ciphertext = securityService.encryptWithPublicKey(
          plaintext,
          publicKey,
        );

        final decrypted = securityService.decryptWithPrivateKey(ciphertext);

        expect(decrypted, equals(plaintext));
      });

      test('encrypts with PEM-formatted public key', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        final publicKeyPem = securityService.publicKeyPem!;
        final plaintext = 'Test message';

        final ciphertext = securityService.encryptWithPublicKeyPem(
          plaintext,
          publicKeyPem,
        );

        expect(ciphertext, isNotEmpty);
        expect(ciphertext, isNot(equals(plaintext)));
      });

      test('decrypts PEM-encrypted message', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        final publicKeyPem = securityService.publicKeyPem!;
        final plaintext = 'Test message';

        final ciphertext = securityService.encryptWithPublicKeyPem(
          plaintext,
          publicKeyPem,
        );

        final decrypted = securityService.decryptWithPrivateKey(ciphertext);

        expect(decrypted, equals(plaintext));
      });
    });

    group('key management', () {
      test('generates valid public key', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        expect(securityService.publicKey, isNotNull);
      });

      test('generates valid PEM-formatted public key', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        final publicKeyPem = securityService.publicKeyPem;

        expect(publicKeyPem, isNotNull);
        expect(publicKeyPem, isNotEmpty);
        // PEM format starts with "PUBLIC:" prefix instead of "BEGIN PUBLIC KEY"
        expect(publicKeyPem, startsWith('PUBLIC:'));
      });

      test('public key PEM can be used for encryption', () async {
        await securityService.initialize();
        await securityService.generateKeyPair();

        final publicKeyPem = securityService.publicKeyPem!;
        final plaintext = 'Test';

        expect(
          () =>
              securityService.encryptWithPublicKeyPem(plaintext, publicKeyPem),
          returnsNormally,
        );
      });

      test('has AES key for message encryption', () async {
        await securityService.initialize();
        await securityService.generateAesKey();

        expect(securityService.aesKeyBase64, isNotNull);
        expect(securityService.aesKeyBase64, isNotEmpty);
      });
    });
  });
}
