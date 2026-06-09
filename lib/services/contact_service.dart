import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:prism/api/api_client.dart';
import 'package:prism/models/contact_sync_result.dart';

class ContactService {
  final ApiClient _apiClient = ApiClient();

  /// Request contacts permission from the user
  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.contacts.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // User has permanently denied permission — direct to Settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Read all contacts from the phone (requires permission).
  /// Only fetches phone numbers — skips addresses, emails, etc. — to keep
  /// each contact object small and speed up the sync payload.
  Future<List<Contact>> getPhoneContacts() async {
    try {
      final hasPermission = await Permission.contacts.isGranted;
      if (!hasPermission) {
        debugPrint('Contacts permission not granted');
        return [];
      }
      // withProperties: true fetches phones, emails, addresses, etc.
      // We only need phones + displayName, but flutter_contacts doesn't let
      // us cherry-pick sub-properties — setting withProperties: true is still
      // required to get phone numbers. The savings come from batching below.
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      return contacts;
    } catch (e) {
      debugPrint('Error reading contacts: $e');
      return [];
    }
  }

  /// Convert a raw phone string to {display_name, raw_phone, country_code} maps
  /// for the V2 /contacts/sync bulk payload. Extracts ALL phone numbers from the contact.
  Iterable<Map<String, String>> _buildContactPayloads(Contact contact) {
    return contact.phones.map((phoneData) {
      final phone = phoneData.number;
      String countryCode = '91'; // Default country code for local numbers
      String rawPhone = phone;

      if (phone.startsWith('+')) {
        final match = RegExp(r'^\+(\d{1,3})(.+)').firstMatch(phone);
        if (match != null) {
          countryCode = match.group(1)!;
          rawPhone = match.group(2)!.replaceAll(RegExp(r'[^\d]'), '');
        }
      } else {
        rawPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
        // Strip leading zero if present (common local formatting)
        if (rawPhone.startsWith('0')) {
          rawPhone = rawPhone.substring(1);
        }
      }

      return {
        'display_name': contact.displayName,
        'raw_phone': rawPhone,
        'country_code': countryCode,
      };
    });
  }

  Future<ContactSyncResult> _enrichWithAllLocalContacts(ContactSyncResult result) async {
    final contacts = await getPhoneContacts();
    if (contacts.isEmpty) return result;

    final onPlatformNames = result.onPlatform
        .map((u) => u.contactName)
        .whereType<String>()
        .toSet();

    // The backend might limit the number of recommend invite targets.
    // To ensure ALL local contacts are listed in "Invite to Prism",
    // we explicitly reconstruct notOnPlatform using all our local contacts.
    final allNotOnPlatform = contacts
        .where((c) =>
            c.displayName.isNotEmpty &&
            (!onPlatformNames.contains(c.displayName)))
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
    }).toList();

    allNotOnPlatform.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    return ContactSyncResult(
      onPlatform: result.onPlatform,
      notOnPlatform: allNotOnPlatform,
      unknownFaceRecommendations: result.unknownFaceRecommendations,
    );
  }

  /// V2 Bulk sync: upload entire phonebook.
  /// We send the entire payload in a single request because /contacts/sync
  /// typically performs a full replacement on the backend.
  Future<ContactSyncResult?> syncContactsToBackend(String userId) async {
    try {
      final contacts = await getPhoneContacts();

      if (contacts.isEmpty) {
        debugPrint('[ContactService] No contacts to sync');
        return ContactSyncResult(onPlatform: [], notOnPlatform: []);
      }

      // Build payload — expand all valid phone numbers for each contact
      final payload = contacts
          .where((c) => c.phones.isNotEmpty && c.displayName.isNotEmpty)
          .expand(_buildContactPayloads)
          .toList();

      debugPrint(
        '[ContactService] Syncing ${payload.length} phone numbers via POST /contacts/sync',
      );

      final result = await _apiClient.syncContacts(
        userId: userId,
        contacts: payload,
      );

      final enrichedResult = await _enrichWithAllLocalContacts(result);

      debugPrint(
        '[ContactService] Sync complete: '
        '${enrichedResult.onPlatform.length} on-platform, '
        '${enrichedResult.notOnPlatform.length} invite targets',
      );

      return enrichedResult;
    } catch (e) {
      debugPrint('[ContactService] Error syncing contacts: $e');
      return null;
    }
  }

  /// Full sync flow: request permission → sync contacts → return result
  Future<ContactSyncResult?> requestPermissionAndSyncContacts(
    String userId,
  ) async {
    final hasPermission = await requestContactsPermission();
    if (!hasPermission) {
      debugPrint('[ContactService] Contacts permission denied');
      return null;
    }
    return await syncContactsToBackend(userId);
  }

  /// Fetch cached recommendations from the backend (no re-read of phonebook)
  Future<ContactSyncResult?> getRecommendations(String userId) async {
    try {
      final result = await _apiClient.getContactRecommendations(userId: userId);
      return await _enrichWithAllLocalContacts(result);
    } catch (e) {
      debugPrint('[ContactService] Error fetching recommendations: $e');
      return null;
    }
  }

  /// Check if user has contacts synced in backend
  Future<bool> hasContactsInBackend(String userId) async {
    try {
      final contacts = await _apiClient.getContacts(userId: userId);
      return contacts.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking backend contacts: $e');
      return false;
    }
  }

  /// Update the permission state on the backend
  Future<void> updateSyncStatus(String userId, String status) async {
    try {
      await _apiClient.updateContactSyncStatus(
        userId: userId,
        status: status,
      );
    } catch (e) {
      debugPrint('[ContactService] Error updating sync status: $e');
    }
  }
}
