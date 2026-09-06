import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/domain/memo_markup.dart';

void main() {
  test('plain quita los marcadores y deja el texto', () {
    expect(MemoMarkup.plain('El plazo es **3 meses** y el silencio *positivo*.'), 'El plazo es 3 meses y el silencio positivo.');
  });

  test('toSpan marca negrita y cursiva', () {
    const base = TextStyle(fontWeight: FontWeight.w500);
    final span = MemoMarkup.toSpan('Ver **alzada** o *reposición*.', base);
    final children = span.children!.cast<TextSpan>();
    expect(children.map((item) => item.text), ['Ver ', 'alzada', ' o ', 'reposición', '.']);
    expect(children[1].style?.fontWeight, FontWeight.w800);
    expect(children[3].style?.fontStyle, FontStyle.italic);
  });

  test('wrap envuelve la selección y la puede quitar', () {
    final controller = TextEditingController(text: '3 meses');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
    MemoMarkup.wrap(controller, '**');
    expect(controller.text, '**3 meses**');
    MemoMarkup.wrap(controller, '**');
    expect(controller.text, '3 meses');
  });
}
