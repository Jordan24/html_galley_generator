class StringCleaner {
  /// Cleans up common unicode space/quote/dash variations and trims excess whitespace.
  /// If [normalizeHyphenSpaces] is true, replaces ' - ' with '-'.
  static String clean(String text, {bool normalizeHyphenSpaces = false}) {
    if (text.isEmpty) return '';
    var result = text.trim()
        .replaceAll('\uFFFD', "'")
        .replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u2032\u2035\u02BC\u02BD\u02C8\u02CA\u02CB\u00B4\u0060\u0090\u0091\u0092]'), "'")
        .replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F\u2033\u2036\u0093\u0094\u00AB\u00BB]'), '"')
        .replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'), '-')
        .replaceAll('\uFB01', 'fi')
        .replaceAll('\uFB02', 'fl')
        .replaceAll(RegExp(r'[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\uFEFF]'), ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalizeHyphenSpaces) {
      result = result.replaceAll(' - ', '-');
    }
    return result;
  }

  /// Replaces pairs of markers with open/close HTML tags.
  static String replacePairs(String text, String marker, String openTag, String closeTag) {
    int index = 0;
    bool isOpen = false;
    final buffer = StringBuffer();
    
    while (index < text.length) {
      if (text.startsWith(marker, index)) {
        if (!isOpen) {
          buffer.write(openTag);
          isOpen = true;
        } else {
          buffer.write(closeTag);
          isOpen = false;
        }
        index += marker.length;
      } else {
        buffer.write(text[index]);
        index++;
      }
    }
    
    String result = buffer.toString();
    if (isOpen) {
      result += closeTag;
    }
    return result;
  }

  /// Formats date to 'Mon YYYY' format (e.g. 'Jan 2026').
  static String formatMonYYYY(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
