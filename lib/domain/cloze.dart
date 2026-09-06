class ClozePart {
  const ClozePart.text(this.value) : blank = false;
  const ClozePart.blank(this.value) : blank = true;

  final String value;
  final bool blank;
}

/// Huecos marcados como `{{dato}}` en el texto del hecho.
abstract final class Cloze {
  static final token = RegExp(r'\{\{(.+?)\}\}');

  static bool hasBlanks(String text) => token.hasMatch(text);

  static List<String> blanks(String text) {
    return [
      for (final match in token.allMatches(text)) match.group(1)!.trim(),
    ].where((item) => item.isNotEmpty).toList();
  }

  static List<ClozePart> parse(String text) {
    final parts = <ClozePart>[];
    var start = 0;
    for (final match in token.allMatches(text)) {
      if (match.start > start) {
        parts.add(ClozePart.text(text.substring(start, match.start)));
      }
      final blank = match.group(1)!.trim();
      if (blank.isNotEmpty) parts.add(ClozePart.blank(blank));
      start = match.end;
    }
    if (start < text.length) {
      parts.add(ClozePart.text(text.substring(start)));
    }
    return parts;
  }

  static String normalize(String raw) {
    final folded = raw.trim().toLowerCase().split('').map((ch) => _fold[ch] ?? ch).join();
    return folded.replaceAll(RegExp(r'[.,;:·]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool same(String expected, String actual) {
    return normalize(expected) == normalize(actual) && normalize(expected).isNotEmpty;
  }

  static const _fold = {
    'á': 'a',
    'à': 'a',
    'é': 'e',
    'è': 'e',
    'í': 'i',
    'ì': 'i',
    'ó': 'o',
    'ò': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
}
