import 'package:intl/intl.dart';

/// Centralized Date & Time Engine for ShopSilo.
/// Guarantees that all UTC timestamps from PostgreSQL & GoBackend are properly
/// parsed and converted to device Local Time (Indian Standard Time, Asia/Kolkata).
class AppDateTimeUtils {
  AppDateTimeUtils._();

  /// Parse any raw date (String, DateTime, int, or null) into a local DateTime.
  /// If the raw string is an ISO string without timezone indicator, it safely
  /// interprets it as UTC first so `.toLocal()` converts properly to the device timezone.
  static DateTime parseToLocal(dynamic raw, [DateTime? fallback]) {
    if (raw == null) return fallback ?? DateTime.now();
    if (raw is DateTime) return raw.toLocal();

    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null' || str == '0') return fallback ?? DateTime.now();

    // Numeric epoch timestamp (milliseconds or seconds)
    final numVal = int.tryParse(str);
    if (numVal != null) {
      if (str.length == 10) {
        // Unix seconds
        return DateTime.fromMillisecondsSinceEpoch(numVal * 1000).toLocal();
      } else if (str.length >= 13) {
        // Unix milliseconds
        return DateTime.fromMillisecondsSinceEpoch(numVal).toLocal();
      }
    }

    String formattedStr = str;
    // If date string does not specify timezone (neither 'Z' nor offset like '+05:30' or '-04:00'),
    // ensure it is treated as UTC ISO-8601 so .toLocal() converts it to device local timezone (IST).
    if (!formattedStr.endsWith('Z') && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(formattedStr)) {
      formattedStr = '${formattedStr.replaceAll(' ', 'T')}Z';
    }

    final parsed = DateTime.tryParse(formattedStr) ?? DateTime.tryParse(str);
    if (parsed == null) return fallback ?? DateTime.now();
    return parsed.toLocal();
  }

  /// Parse nullable raw date into local DateTime, returning null if empty or invalid.
  static DateTime? parseToLocalNullable(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null' || str == '0') return null;

    return parseToLocal(raw);
  }

  /// Format time in 12-hour format with AM/PM (e.g. "10:14 AM", "09:30 PM").
  static String formatTime(dynamic raw, {bool withPeriod = true}) {
    final dt = parseToLocal(raw);
    try {
      final formatter = withPeriod ? DateFormat('hh:mm a') : DateFormat('HH:mm');
      return formatter.format(dt);
    } catch (_) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return withPeriod ? '$hour:$min $period' : '${dt.hour.toString().padLeft(2, '0')}:$min';
    }
  }

  /// Format date e.g. "11 Oct 2026".
  static String formatDate(dynamic raw, {String pattern = 'dd MMM yyyy'}) {
    final dt = parseToLocal(raw);
    try {
      return DateFormat(pattern).format(dt);
    } catch (_) {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
  }

  /// Format date and time e.g. "11 Oct, 10:14 AM".
  static String formatDateTime(dynamic raw, {bool includeYear = false}) {
    final dt = parseToLocal(raw);
    try {
      final pattern = includeYear ? 'dd MMM yyyy, hh:mm a' : 'dd MMM, hh:mm a';
      return DateFormat(pattern).format(dt);
    } catch (_) {
      return '${dt.day}/${dt.month} ${formatTime(dt)}';
    }
  }

  /// Returns friendly relative time: "Today, 10:14 AM", "Yesterday, 04:30 PM", or "11 Oct, 10:14 AM".
  static String formatRelativeDate(dynamic raw) {
    final dt = parseToLocal(raw);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);

    final diffDays = today.difference(itemDate).inDays;
    if (diffDays == 0) {
      return 'Today, ${formatTime(dt)}';
    } else if (diffDays == 1) {
      return 'Yesterday, ${formatTime(dt)}';
    } else if (diffDays == -1) {
      return 'Tomorrow, ${formatTime(dt)}';
    }
    return formatDateTime(dt);
  }

  /// Returns remaining time string e.g. "45 mins left" or "Expired".
  static String formatTimeRemaining(dynamic rawExpiry) {
    final expiry = parseToLocalNullable(rawExpiry);
    if (expiry == null) return '';

    final now = DateTime.now();
    if (now.isAfter(expiry)) {
      return 'Expired';
    }

    final diff = expiry.difference(now);
    if (diff.inHours >= 1) {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      return mins > 0 ? '$hours hr $mins min left' : '$hours hr left';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} mins left';
    } else {
      return 'Expiring soon';
    }
  }
}
