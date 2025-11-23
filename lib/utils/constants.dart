import 'package:flutter/material.dart';

const kPrimaryColor = Colors.blue;

// API Configuration
class ApiConstants {
  // Base URL - Update this with your actual backend URL
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';

  // User endpoints
  static const String getCurrentUser = '/users/me';
  static const String updateProfile = '/users/me';
  static const String uploadProfilePicture = '/users/me/profile-picture';
  static const String reregisterFace = '/users/me/face/reregister';
  static const String addContact = '/users/me/contacts';
  static const String getContacts = '/users/me/contacts';

  // Friends endpoints
  static const String searchFriends = '/friends/search';
  static const String sendFriendRequest = '/friends/request';
  static const String getFriends = '/friends';
  static const String getSentRequests = '/friends/sent';
  static const String acceptFriendRequest =
      '/friends/'; // + friendship_id + /accept
  static const String rejectFriendRequest =
      '/friends/'; // + friendship_id + /reject

  // Images endpoints
  static const String uploadImages = '/images/upload';
  static const String getGallery = '/images/gallery';
  static const String toggleImageStatus =
      '/images/'; // + image_id + /toggle/ + field
  static const String batchUpdateStatus = '/images/batch/update';
  static const String emptyBin = '/images/bin/empty';
  static const String batchDelete = '/images/batch/delete';
  static const String updateImageDescription =
      '/images/'; // + image_id + /description
  static const String getSharedGallery = '/images/friend/'; // + friend_id
  static const String checkBatchStatus = '/images/batch/'; // + batch_id
  static const String confirmShare = '/images/share/confirm';

  // Notifications endpoints
  static const String getNotifications = '/notifications';
  static const String acceptNotification =
      '/notifications/'; // + notification_id + /accept
  static const String rejectNotification =
      '/notifications/'; // + notification_id + /reject
}
