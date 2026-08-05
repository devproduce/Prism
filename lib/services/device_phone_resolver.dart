import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prism/models/resolved_phone.dart';
import 'package:prism/utils/phone_parser.dart';

/// Resolves the device owner's phone number using a layered fallback chain.
///
/// Priority:
/// 1. Prism account phone (signup / settings) — most reliable for logged-in users
/// 2. Android "Me" profile contact — no extra permission beyond contacts
/// 3. SIM / telephony line — Android only, often empty on modern devices
class DevicePhoneResolver {
  static const _channel = MethodChannel('in.prismapp.prism/device_phone');

  /// Returns the best available owner phone, or null if nothing could be resolved.
  Future<ResolvedPhone?> resolve({
    String? accountCountryCode,
    String? accountPhone,
    String? accountDisplayName,
  }) async {
    final fromAccount = _fromAccount(
      countryCode: accountCountryCode,
      phone: accountPhone,
      displayName: accountDisplayName,
    );
    if (fromAccount != null) {
      debugPrint(
        '[DevicePhoneResolver] Using account phone (${fromAccount.dedupeKey})',
      );
      return fromAccount;
    }

    if (!Platform.isAndroid) {
      debugPrint('[DevicePhoneResolver] No account phone; iOS has no device API');
      return null;
    }

    final fromProfile = await _fromAndroidProfile();
    if (fromProfile != null) {
      debugPrint(
        '[DevicePhoneResolver] Using Android profile phone (${fromProfile.dedupeKey})',
      );
      return fromProfile;
    }

    final fromSim = await _fromSim();
    if (fromSim != null) {
      debugPrint(
        '[DevicePhoneResolver] Using SIM phone (${fromSim.dedupeKey})',
      );
      return fromSim;
    }

    debugPrint('[DevicePhoneResolver] Could not resolve owner phone');
    return null;
  }

  ResolvedPhone? _fromAccount({
    String? countryCode,
    String? phone,
    String? displayName,
  }) {
    final digits = phone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
    if (digits.isEmpty) return null;

    final cc = (countryCode ?? PhoneParser.defaultCountryCode)
        .replaceAll(RegExp(r'[^\d]'), '');
    if (cc.isEmpty) return null;

    final local = digits.startsWith(cc) && digits.length > cc.length
        ? digits.substring(cc.length)
        : digits;

    if (!PhoneParser.isValidLocalNumber(local)) return null;

    return ResolvedPhone(
      countryCode: cc,
      rawPhone: local,
      source: ResolvedPhoneSource.account,
      displayName: displayName,
    );
  }

  Future<ResolvedPhone?> _fromAndroidProfile() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getProfilePhoneNumbers',
      );
      return _firstValidCandidate(raw, ResolvedPhoneSource.androidProfile);
    } on PlatformException catch (e) {
      debugPrint('[DevicePhoneResolver] Profile read failed: ${e.message}');
      return null;
    }
  }

  Future<ResolvedPhone?> _fromSim() async {
    if (!await _ensurePhonePermission()) return null;

    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getSimPhoneNumbers',
      );
      return _firstValidCandidate(raw, ResolvedPhoneSource.sim);
    } on PlatformException catch (e) {
      debugPrint('[DevicePhoneResolver] SIM read failed: ${e.message}');
      return null;
    }
  }

  ResolvedPhone? _firstValidCandidate(
    List<dynamic>? entries,
    ResolvedPhoneSource source,
  ) {
    if (entries == null || entries.isEmpty) return null;

    for (final entry in entries) {
      if (entry is! Map) continue;
      final number = entry['number']?.toString() ?? '';
      if (number.isEmpty) continue;

      final parsed = PhoneParser.parse(number);
      final local = PhoneParser.normalizeLocalNumber(
        parsed.countryCode,
        parsed.rawPhone,
      );
      if (!PhoneParser.isValidLocalNumber(local)) continue;

      return ResolvedPhone(
        countryCode: parsed.countryCode,
        rawPhone: local,
        source: source,
        displayName: entry['displayName']?.toString(),
      );
    }
    return null;
  }

  Future<bool> _ensurePhonePermission() async {
    var status = await Permission.phone.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      status = await Permission.phone.request();
      return status.isGranted;
    }
    return false;
  }
}
