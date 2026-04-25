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

  /// Read all contacts from the phone (requires permission)
  Future<List<Contact>> getPhoneContacts() async {
    try {
      final hasPermission = await Permission.contacts.isGranted;
      if (!hasPermission) {
        debugPrint('Contacts permission not granted');
        return [];
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      return contacts;
    } catch (e) {
      debugPrint('Error reading contacts: $e');
      return [];
    }
  }

  /// Convert a raw phone string to {display_name, raw_phone, country_code} map
  /// for the V2 /contacts/sync bulk payload.
  Map<String, String> _buildContactPayload(Contact contact) {
    final phone = contact.phones.first.number;
    String countryCode = '';
    String rawPhone = phone;

    if (phone.startsWith('+')) {
      final match = RegExp(r'^\+(\d{1,3})(.+)').firstMatch(phone);
      if (match != null) {
        countryCode = match.group(1)!;
        rawPhone = match.group(2)!.replaceAll(RegExp(r'[^\d]'), '');
      }
    } else {
      rawPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    }

    return {
      'display_name': contact.displayName,
      'raw_phone': rawPhone,
      'country_code': countryCode,
    };
  }

  /// V2 Bulk sync: upload entire phonebook in one call.
  /// Returns [ContactSyncResult] with on_platform and not_on_platform lists.
  Future<ContactSyncResult?> syncContactsToBackend(String userId) async {
    try {
      final contacts = await getPhoneContacts();

      if (contacts.isEmpty) {
        debugPrint('[ContactService] No contacts to sync');
        return ContactSyncResult(onPlatform: [], notOnPlatform: []);
      }

      // Build payload — skip contacts without a phone number or display name
      final payload = contacts
          .where((c) => c.phones.isNotEmpty && c.displayName.isNotEmpty)
          .map(_buildContactPayload)
          .toList();

      debugPrint(
        '[ContactService] Syncing ${payload.length} contacts via POST /contacts/sync',
      );

      final result = await _apiClient.syncContacts(
        userId: userId,
        contacts: payload,
      );

      debugPrint(
        '[ContactService] Sync complete: '
        '${result.onPlatform.length} on-platform, '
        '${result.notOnPlatform.length} invite targets',
      );

      return result;
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
      return await _apiClient.getContactRecommendations(userId: userId);
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
