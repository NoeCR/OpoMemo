import 'package:flutter/material.dart';

/// Negrita `**texto**` y cursiva `*texto*` en respuestas y aclaraciones.
abstract final class MemoMarkup {
  static final _token = RegExp(
    r'\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|\*(.+?)\*',
    dotAll: true,
  );

  static String plain(String source) {
    return source.replaceAllMapped(_token, (match) => match.group(1) ?? match.group(2) ?? match.group(3) ?? '');
  }

  static TextSpan toSpan(String source, TextStyle base, {Color? accent}) {
    if (!_token.hasMatch(source)) {
      return TextSpan(text: source, style: base);
    }
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in _token.allMatches(source)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: source.substring(cursor, match.start), style: base));
      }
      final boldItalic = match.group(1);
      final bold = match.group(2);
      final italic = match.group(3);
      if (boldItalic != null) {
        children.add(
          TextSpan(
            text: boldItalic,
            style: base.copyWith(
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: accent ?? base.color,
            ),
          ),
        );
      } else if (bold != null) {
        children.add(
          TextSpan(
            text: bold,
            style: base.copyWith(
              fontWeight: FontWeight.w800,
              color: accent ?? base.color,
            ),
          ),
        );
      } else if (italic != null) {
        children.add(
          TextSpan(
            text: italic,
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < source.length) {
      children.add(TextSpan(text: source.substring(cursor), style: base));
    }
    return TextSpan(style: base, children: children);
  }

  static void wrap(TextEditingController controller, String marker) {
    final value = controller.value;
    final selection = value.selection;
    if (!selection.isValid) return;
    final text = value.text;
    final start = selection.start;
    final end = selection.end;
    if (start == end) {
      final inserted = '$marker$marker';
      controller.value = value.copyWith(
        text: text.replaceRange(start, end, inserted),
        selection: TextSelection.collapsed(offset: start + marker.length),
        composing: TextRange.empty,
      );
      return;
    }
    final selected = text.substring(start, end);
    if (selected.startsWith(marker) &&
        selected.endsWith(marker) &&
        selected.length > marker.length * 2) {
      final inner = selected.substring(marker.length, selected.length - marker.length);
      controller.value = value.copyWith(
        text: text.replaceRange(start, end, inner),
        selection: TextSelection(baseOffset: start, extentOffset: start + inner.length),
        composing: TextRange.empty,
      );
      return;
    }
    if (start >= marker.length && end + marker.length <= text.length) {
      final before = text.substring(start - marker.length, start);
      final after = text.substring(end, end + marker.length);
      if (before == marker && after == marker) {
        controller.value = value.copyWith(
          text: text.replaceRange(start - marker.length, end + marker.length, selected),
          selection: TextSelection(
            baseOffset: start - marker.length,
            extentOffset: start - marker.length + selected.length,
          ),
          composing: TextRange.empty,
        );
        return;
      }
    }
    final wrapped = '$marker$selected$marker';
    controller.value = value.copyWith(
      text: text.replaceRange(start, end, wrapped),
      selection: TextSelection(baseOffset: start, extentOffset: start + wrapped.length),
      composing: TextRange.empty,
    );
  }
}
