import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:prism/api/api_client.dart';

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
      // User has permanently denied permission
      // Direct them to settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Read contacts from the phone
  Future<List<Contact>> getPhoneContacts() async {
    try {
      // Check permission first
      final hasPermission = await Permission.contacts.isGranted;
      if (!hasPermission) {
        debugPrint('Contacts permission not granted');
        return [];
      }

      // Fetch all contacts with phone numbers
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      return contacts;
    } catch (e) {
      debugPrint('Error reading contacts: $e');
      return [];
    }
  }

  /// Sync contacts to backend
  Future<bool> syncContactsToBackend(String userId) async {
    try {
      // Get phone contacts
      final contacts = await getPhoneContacts();

      if (contacts.isEmpty) {
        debugPrint('No contacts to sync');
        return true;
      }

      debugPrint('Syncing ${contacts.length} contacts to backend...');

      int successCount = 0;
      int failureCount = 0;

      // Add each contact to backend
      for (final contact in contacts) {
        // Skip contacts without phone numbers or display name
        if (contact.phones.isEmpty) continue;
        if (contact.displayName.isEmpty) continue;

        // Get the first phone number
        final phone = contact.phones.first.number;
        if (phone.isEmpty) continue;

        // Parse country code and phone number
        // Simple parsing - assumes format like +1234567890 or just digits
        String? countryCode;
        String phoneNumber = phone;

        if (phone.startsWith('+')) {
          // Try to extract country code (1-3 digits after +)
          final match = RegExp(r'^\+(\d{1,3})(.+)').firstMatch(phone);
          if (match != null) {
            countryCode = match.group(1);
            phoneNumber = match.group(2)!.replaceAll(RegExp(r'[^\d]'), '');
          }
        } else {
          // Remove non-digit characters
          phoneNumber = phone.replaceAll(RegExp(r'[^\d]'), '');
        }

        try {
          await _apiClient.addContact(
            userId: userId,
            fullName: contact.displayName,
            phoneNumber: phoneNumber,
            countryCode: countryCode,
          );
          successCount++;
        } catch (e) {
          debugPrint('Failed to add contact ${contact.displayName}: $e');
          failureCount++;
        }
      }

      debugPrint(
        'Contact sync complete: $successCount succeeded, $failureCount failed',
      );
      return successCount > 0;
    } catch (e) {
      debugPrint('Error syncing contacts: $e');
      return false;
    }
  }

  /// Full sync flow: request permission and sync contacts
  Future<bool> requestPermissionAndSyncContacts(String userId) async {
    // Request permission
    final hasPermission = await requestContactsPermission();

    if (!hasPermission) {
      debugPrint('Contacts permission denied');
      return false;
    }

    // Sync contacts to backend
    return await syncContactsToBackend(userId);
  }

  /// Check if user has contacts in backend
  Future<bool> hasContactsInBackend(String userId) async {
    try {
      final contacts = await _apiClient.getContacts(userId: userId);
      return contacts.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking backend contacts: $e');
      return false;
    }
  }
}
