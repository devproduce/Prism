/// Relative time string similar to date-fns `formatDistanceToNow` with suffix.
String formatDistanceToNow(DateTime date) {
  final diff = DateTime.now().difference(date.toLocal());

  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes;
    return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  if (diff.inDays < 7) {
    final days = diff.inDays;
    return days == 1 ? '1 day ago' : '$days days ago';
  }
  if (diff.inDays < 30) {
    final weeks = diff.inDays ~/ 7;
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  if (diff.inDays < 365) {
    final months = diff.inDays ~/ 30;
    return months == 1 ? '1 month ago' : '$months months ago';
  }
  final years = diff.inDays ~/ 365;
  return years == 1 ? '1 year ago' : '$years years ago';
}
