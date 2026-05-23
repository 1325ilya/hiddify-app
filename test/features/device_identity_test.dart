import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/settings/data/request_diagnostics_store.dart';

void main() {
  group('Device Identity Lab Logic Tests', () {
    test('Token Masking Logic', () {
      expect(maskToken("123456"), "***");
      expect(maskToken("abcdef123456"), "abc...456");
    });

    test('URL Masking Logic', () {
      final url1 = "https://example.com/sub/abc-def-1234-uuid-xyz?token=mysecrettoken&name=john";
      final maskedUrl1 = maskUrl(url1);
      expect(maskedUrl1, contains("token=mys...ken"));
      expect(maskedUrl1, contains("name=john"));

      final url2 = "https://user:password@domain.com/path?key=123456789";
      final maskedUrl2 = maskUrl(url2);
      expect(maskedUrl2, contains("user:***"));
      expect(maskedUrl2, contains("key=123...789"));
    });

    test('Header Masking Logic', () {
      final headers = {
        "User-Agent": "HiddifyNext/1.0.0",
        "Authorization": "Bearer 1234567890abcdef",
        "profile-title": "My Private Profile Title",
        "x-api-key": "secretapikeyvalue",
        "content-type": "application/json",
      };

      final masked = maskHeaders(headers);
      expect(masked["User-Agent"], "HiddifyNext/1.0.0");
      expect(masked["Authorization"], "Bea...def");
      expect(masked["profile-title"], "My ...tle");
      expect(masked["x-api-key"], "sec...lue");
      expect(masked["content-type"], "application/json");
    });

    test('Category Detection', () {
      expect(getRequestCategory("/api/v1/profile/123", "https://api.com"), "Subscription");
      expect(getRequestCategory("/update", "https://hiddify.com/app-update"), "App Update");
      expect(getRequestCategory("/config/options", "https://localhost"), "Config/Settings");
      expect(getRequestCategory("/auth/token", "https://my-auth.com"), "Auth");
      expect(getRequestCategory("/users/list", "https://api.github.com"), "General API");
    });
  });
}
