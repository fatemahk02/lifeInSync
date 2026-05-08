class InputSanitizer {
  InputSanitizer._();

  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _multiWhitespace = RegExp(r'\s+');
  static final RegExp _safeNameChars = RegExp(r"[^a-zA-Z0-9 .,'_-]");
  static final RegExp _safeHabitChars = RegExp(r"[^a-zA-Z0-9 .,'!?()_+-]");
  static final RegExp _phoneAllowedChars = RegExp(r'[^0-9+]');
  static final RegExp _otpDigitsOnly = RegExp(r'[^0-9]');

  static String sanitizeName(String value, {int maxLength = 80}) {
    final cleaned = _normalizeWhitespace(_stripControl(value))
        .replaceAll(_safeNameChars, '');
    return _truncate(cleaned, maxLength);
  }

  static String sanitizeEmail(String value) {
    final cleaned = _stripControl(value).trim().toLowerCase().replaceAll(' ', '');
    return _truncate(cleaned, 160);
  }

  static String sanitizeHabitName(String value, {int maxLength = 80}) {
    final cleaned = _normalizeWhitespace(_stripControl(value))
        .replaceAll(_safeHabitChars, '');
    return _truncate(cleaned, maxLength);
  }

  static String sanitizePhone(String value) {
    var cleaned = _stripControl(value).replaceAll(' ', '').replaceAll('-', '');
    cleaned = cleaned.replaceAll(_phoneAllowedChars, '');

    if (cleaned.startsWith('+')) {
      final digits = cleaned.substring(1).replaceAll('+', '');
      return '+$digits';
    }

    return cleaned.replaceAll('+', '');
  }

  static String sanitizeOtp(String value) {
    return _stripControl(value).replaceAll(_otpDigitsOnly, '');
  }

  static String _stripControl(String value) {
    return value.replaceAll(_controlChars, '');
  }

  static String _normalizeWhitespace(String value) {
    return value.trim().replaceAll(_multiWhitespace, ' ');
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
