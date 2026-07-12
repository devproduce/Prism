import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/contact_sync_result.dart';
import 'package:prism/models/resolved_phone.dart';
import 'package:prism/services/device_phone_resolver.dart';
import 'package:prism/utils/phone_parser.dart';

class ContactService {
  final ApiClient _apiClient = ApiClient();
  final DevicePhoneResolver _devicePhoneResolver = DevicePhoneResolver();

  static const int _syncBatchSize = 300;

  Future<bool> _ensureAuthenticated() async {
    final ready = await _apiClient.ensureAuthenticated();
    if (!ready) {
      debugPrint('[ContactService] Skipping API call: no auth token');
    }
    return ready;
  }

  /// Whether the app can read the device phonebook right now.
  Future<bool> hasContactsPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted || status.isLimited;
  }

  /// Request contacts permission — shows the native OS dialog when needed.
  Future<bool> requestContactsPermission() async {
    var status = await Permission.contacts.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }

    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (granted) return true;

    status = await Permission.contacts.status;
    return status.isGranted || status.isLimited;
  }

  /// Read all contacts from the phone (requires permission).
  Future<List<Contact>> getPhoneContacts() async {
    try {
      if (!await hasContactsPermission()) {
        debugPrint('[ContactService] Contacts permission not granted');
        return [];
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      return contacts;
    } catch (e) {
      debugPrint('[ContactService] Error reading contacts: $e');
      return [];
    }
  }

  Iterable<Map<String, String>> _buildContactPayloads(Contact contact) {
    return contact.phones.map((phoneData) {
      final parsed = PhoneParser.parse(phoneData.number);
      return {
        'display_name': contact.displayName,
        'raw_phone': parsed.rawPhone,
        'country_code': parsed.countryCode,
      };
    }).where(
      (entry) => PhoneParser.isValidLocalNumber(entry['raw_phone'] ?? ''),
    );
  }

  List<Map<String, String>> _dedupePayload(List<Map<String, String>> payload) {
    final seen = <String>{};
    final deduped = <Map<String, String>>[];

    for (final entry in payload) {
      final key = '${entry['country_code']}|${entry['raw_phone']}';
      if (seen.add(key)) {
        deduped.add(entry);
      }
    }

    return deduped;
  }

  List<Map<String, String>> _withOwnerPhone(
    List<Map<String, String>> payload,
    ResolvedPhone ownerPhone,
  ) {
    final alreadyPresent = payload.any((entry) {
      final cc = entry['country_code'] ?? '';
      final raw = entry['raw_phone'] ?? '';
      return '$cc$raw' == ownerPhone.dedupeKey;
    });

    if (alreadyPresent) return payload;

    return [ownerPhone.toSyncPayload(), ...payload];
  }

  Future<ContactSyncResult> _enrichWithAllLocalContacts(
    ContactSyncResult result,
  ) async {
    final contacts = await getPhoneContacts();
    if (contacts.isEmpty) return result;

    final onPlatformNames = result.onPlatform
        .map((u) => u.contactName)
        .whereType<String>()
        .toSet();

    final allNotOnPlatform = contacts
        .where(
          (c) =>
              c.displayName.isNotEmpty &&
              (!onPlatformNames.contains(c.displayName)),
        )
        .map((c) {
          String phone = '';
          if (c.phones.isNotEmpty) {
            phone = c.phones.first.number.replaceAll(RegExp(r'[^\d+]'), '');
            if (phone.startsWith('+')) {
              phone = phone.substring(1);
            }
          }
          return NotOnPlatformContact(
            displayName: c.displayName,
            whatsappLink: phone.isNotEmpty ? 'https://wa.me/$phone' : '',
            smsLink: phone.isNotEmpty ? 'sms:$phone' : '',
          );
        })
        .toList();

    allNotOnPlatform.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    return ContactSyncResult(
      onPlatform: result.onPlatform,
      notOnPlatform: allNotOnPlatform,
      unknownFaceRecommendations: result.unknownFaceRecommendations,
    );
  }

  Future<ContactSyncOutcome> _uploadPayloadInBatches(
    String userId,
    List<Map<String, String>> payload,
  ) async {
    if (!await _ensureAuthenticated()) {
      return const ContactSyncOutcome(issue: ContactSyncIssue.uploadFailed);
    }

    final batchCount = (payload.length / _syncBatchSize).ceil();

    for (var batchIndex = 0; batchIndex < batchCount; batchIndex++) {
      final start = batchIndex * _syncBatchSize;
      final end = math.min(start + _syncBatchSize, payload.length);
      final batch = payload.sublist(start, end);

      debugPrint(
        '[ContactService] Uploading batch ${batchIndex + 1}/$batchCount '
        '(${batch.length} numbers)',
      );

      try {
        await _apiClient.syncContacts(contacts: batch);
      } catch (e) {
        debugPrint('[ContactService] Batch upload failed: $e');
        return ContactSyncOutcome(
          issue: ContactSyncIssue.uploadFailed,
        );
      }
    }

    try {
      final recommendations = await _apiClient.getContactRecommendations();
      final enriched = await _enrichWithAllLocalContacts(recommendations);

      debugPrint(
        '[ContactService] Sync complete: '
        '${enriched.onPlatform.length} on-platform, '
        '${enriched.notOnPlatform.length} invite targets',
      );

      return ContactSyncOutcome(result: enriched);
    } catch (e) {
      debugPrint('[ContactService] Error loading recommendations after sync: $e');
      return const ContactSyncOutcome(issue: ContactSyncIssue.uploadFailed);
    }
  }

  Future<ContactSyncOutcome> syncContactsToBackend(
    String userId, {
    String? accountCountryCode,
    String? accountPhone,
    String? accountDisplayName,
  }) async {
    try {
      final contacts = await getPhoneContacts();

      var payload = contacts
          .where((c) => c.phones.isNotEmpty && c.displayName.isNotEmpty)
          .expand(_buildContactPayloads)
          .toList();

      payload = _dedupePayload(payload);

      final ownerPhone = await _devicePhoneResolver.resolve(
        accountCountryCode: accountCountryCode,
        accountPhone: accountPhone,
        accountDisplayName: accountDisplayName,
      );
      if (ownerPhone != null) {
        payload = _dedupePayload(_withOwnerPhone(payload, ownerPhone));
      }

      if (payload.isEmpty) {
        debugPrint('[ContactService] No contacts or owner phone to sync');
        return const ContactSyncOutcome(issue: ContactSyncIssue.noContacts);
      }

      debugPrint(
        '[ContactService] Syncing ${payload.length} unique phone numbers '
        'via POST /contacts/sync'
        '${ownerPhone != null ? ' (owner via ${ownerPhone.source.name})' : ''}',
      );

      return await _uploadPayloadInBatches(userId, payload);
    } catch (e) {
      debugPrint('[ContactService] Error syncing contacts: $e');
      return const ContactSyncOutcome(issue: ContactSyncIssue.uploadFailed);
    }
  }

  Future<ContactSyncOutcome> requestPermissionAndSyncContacts(
    String userId, {
    String? accountCountryCode,
    String? accountPhone,
    String? accountDisplayName,
  }) async {
    final hasPermission = await requestContactsPermission();
    if (!hasPermission) {
      debugPrint('[ContactService] Contacts permission denied');
      await updateSyncStatus(userId, 'denied');
      return const ContactSyncOutcome(issue: ContactSyncIssue.permissionDenied);
    }

    await updateSyncStatus(userId, 'granted');

    return await syncContactsToBackend(
      userId,
      accountCountryCode: accountCountryCode,
      accountPhone: accountPhone,
      accountDisplayName: accountDisplayName,
    );
  }

  Future<ContactSyncResult?> getRecommendations(String userId) async {
    if (!await _ensureAuthenticated()) return null;

    try {
      final result = await _apiClient.getContactRecommendations();
      if (await hasContactsPermission()) {
        return await _enrichWithAllLocalContacts(result);
      }
      return result;
    } catch (e) {
      debugPrint('[ContactService] Error fetching recommendations: $e');
      return null;
    }
  }

  Future<ContactSyncStatus> getContactSyncStatus(String userId) async {
    if (!await _ensureAuthenticated()) {
      return const ContactSyncStatus(contactCount: 0);
    }

    try {
      final status = await _apiClient.getContactSyncStatus();
      final parsed = ContactSyncStatus.fromJson(status);
      debugPrint(
        '[ContactService] Backend sync-status: count=${parsed.contactCount} '
        'stored=${parsed.hasStoredContacts}',
      );
      return parsed;
    } catch (e) {
      debugPrint('[ContactService] Error checking sync-status: $e');
      return const ContactSyncStatus(contactCount: 0);
    }
  }

  Future<bool> hasContactsStoredOnBackend(String userId) async {
    final status = await getContactSyncStatus(userId);
    return status.hasStoredContacts;
  }

  Future<bool> hasContactsInBackend(String userId) async {
    return hasContactsStoredOnBackend(userId);
  }

  Future<void> updateSyncStatus(String userId, String permissionStatus) async {
    if (!await _ensureAuthenticated()) return;

    try {
      await _apiClient.updateContactSyncStatus(
        permissionStatus: permissionStatus,
      );
    } catch (e) {
      debugPrint('[ContactService] Error updating sync status: $e');
    }
  }
}
