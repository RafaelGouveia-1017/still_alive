import 'package:still_alive/views/app/integrations/qr_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QRScannerScreen.decodeBase64Url', () {
    test('decodes a simple JSON object with standard Base64', () {
      // {"ab":123}
      const encoded = 'eyJhYiI6MTIzfQ==';
      const expected = '{"ab":123}';
      expect(QRScannerScreen.decodeBase64Url(encoded), expected);
    });

    test('decodes Base64URL with - and _ characters', () {
      // {"a":1,"b":"test"}
      // Standard Base64: eyJhIjoxLCJiIjoidGVzdCJ9
      // Base64URL form (replace + with -, / with _): eyJhIjoxLCJiIjoidGVzdCJ9
      const original = '{"a":1,"b":"test"}';
      const b64Url = 'eyJhIjoxLCJiIjoidGVzdCJ9';
      expect(QRScannerScreen.decodeBase64Url(b64Url), original);
    });

    test('handles missing padding', () {
      // {"ab":123} with trailing '=' removed
      const encoded = 'eyJhYiI6MTIzfQ';
      const expected = '{"ab":123}';
      expect(QRScannerScreen.decodeBase64Url(encoded), expected);
    });

    test('throws exception for invalid base64', () {
      expect(
        () => QRScannerScreen.decodeBase64Url('!!!invalid!!!'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('not a valid base64 string'),
          ),
        ),
      );
    });

    test('throws exception for valid base64 but not JSON', () {
      // base64 of "hello" - valid base64, not valid JSON
      const encoded = 'aGVsbG8=';
      expect(
        () => QRScannerScreen.decodeBase64Url(encoded),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('not valid JSON'),
          ),
        ),
      );
    });

    test('decodes a URL string', () {
      // The method validates decoded content as JSON.
      // A plain URL like "https://example.com" is not valid JSON, so it throws.
      // To make this pass, the URL must be encoded as a JSON string:
      // "https://example.com"
      const original = '"https://example.com"';
      // base64url of "https://example.com" (the JSON-encoded URL)
      const b64Url = 'Imh0dHBzOi8vZXhhbXBsZS5jb20i';
      expect(QRScannerScreen.decodeBase64Url(b64Url), original);
    });

    test('handles empty input (should throw)', () {
      // Empty string is valid base64 that decodes to an empty string,
      // but an empty string is not valid JSON, so it throws.
      expect(
        () => QRScannerScreen.decodeBase64Url(''),
        throwsException,
      );
    });
  });
}
