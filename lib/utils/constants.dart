import 'package:flutter/material.dart';

const kPrimaryColor = Colors.blue;

// API Configuration
class ApiConstants {
  static const String baseUrl = 'https://backend.prismapp.in';

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String loginVerify = '/auth/login/verify';
  static const String refresh = '/auth/refresh';
  static const String resolveUsername = '/auth/resolve-username';
  static const String verifyLegacyEmail = '/auth/verify-legacy-email';
  static const String resendVerification = '/auth/resend-verification';
  static const String forgotPassword = '/auth/forgot-password';
  static const String googleLogin = '/auth/google-login';
  static const String googleRegister = '/auth/google-register';
  static const String setPassword = '/auth/set-password';
  static const String deleteAccount = '/auth/delete-account';
  static const String cancelDeletion = '/auth/cancel-deletion';

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
  static const String markNotificationsRead = '/notifications/mark-read';
}
