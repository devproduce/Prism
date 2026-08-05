/// Shared phone normalization for contact sync payloads.
class PhoneParser {
  static const String defaultCountryCode = '91';

  /// Typical national number length for the app default market (India).
  static const int _defaultNationalLength = 10;

  /// Split a raw phone string into country code + local digits.
  ///
  /// Strips a duplicated country-code prefix when the device returns values
  /// like `918161234567` or `+918161234567`, so UI does not show
  /// `+91 918161234567`. Bare 10-digit locals that happen to start with `91`
  /// are left intact.
  static ({String countryCode, String rawPhone}) parse(
    String phone, {
    String defaultCountryCode = PhoneParser.defaultCountryCode,
  }) {
    final trimmed = phone.trim();
    var digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return (countryCode: defaultCountryCode, rawPhone: '');
    }

    final hadPlus = trimmed.startsWith('+');

    final strippedDefault = _stripLeadingCountryCode(
      digits,
      defaultCountryCode,
      force: hadPlus,
    );
    if (strippedDefault != null) {
      return (countryCode: defaultCountryCode, rawPhone: strippedDefault);
    }

    if (hadPlus) {
      for (var len = 3; len >= 1; len--) {
        if (digits.length <= len) continue;
        final cc = digits.substring(0, len);
        var local = digits.substring(len);
        local = _stripLeadingCountryCode(local, cc, force: true) ?? local;
        if (isValidLocalNumber(local)) {
          return (countryCode: cc, rawPhone: local);
        }
      }
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
      final stripped = _stripLeadingCountryCode(
        digits,
        defaultCountryCode,
        force: false,
      );
      if (stripped != null) {
        return (countryCode: defaultCountryCode, rawPhone: stripped);
      }
    }

    return (countryCode: defaultCountryCode, rawPhone: digits);
  }

  /// If [digits] starts with [countryCode] and the remainder is a valid local
  /// number, returns the remainder; otherwise null.
  ///
  /// When [force] is false, only strips if the digit string is long enough to
  /// be country-code + national number (avoids turning a 10-digit Indian
  /// mobile like `9181612345` into `81612345`).
  static String? _stripLeadingCountryCode(
    String digits,
    String countryCode, {
    required bool force,
  }) {
    final cc = countryCode.replaceAll(RegExp(r'[^\d]'), '');
    if (cc.isEmpty) return null;
    if (!digits.startsWith(cc) || digits.length <= cc.length) return null;

    final local = digits.substring(cc.length);
    if (!isValidLocalNumber(local)) return null;

    if (!force) {
      final minInternationalLength = cc.length + _defaultNationalLength;
      if (digits.length < minInternationalLength) return null;
    }

    return local;
  }

  /// Ensures [rawPhone] does not still contain [countryCode] as a prefix.
  static String normalizeLocalNumber(String countryCode, String rawPhone) {
    final cc = countryCode.replaceAll(RegExp(r'[^\d]'), '');
    var local = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (local.startsWith('0')) {
      local = local.substring(1);
    }
    // force: false so a real 10-digit local starting with "91" is kept.
    final stripped = _stripLeadingCountryCode(local, cc, force: false);
    return stripped ?? local;
  }

  static bool isValidLocalNumber(String rawPhone) =>
      rawPhone.length >= 7 && rawPhone.length <= 15;
}
