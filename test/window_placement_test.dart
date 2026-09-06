import 'package:flutter_test/flutter_test.dart';
import 'package:opomemo/state/window_placement.dart';

void main() {
  test('sin datos no hay marco que restaurar', () {
    expect(
      WindowPlacement.decodeFrame(x: null, y: 10, width: 1100, height: 760),
      isNull,
    );
  });

  test('el marco se recorta a un tamaño usable', () {
    final frame = WindowPlacement.decodeFrame(
      x: 40,
      y: 80,
      width: 200,
      height: 100,
    );
    expect(frame, isNotNull);
    expect(frame!.left, 40);
    expect(frame.top, 80);
    expect(frame.width, WindowPlacement.minSize.width);
    expect(frame.height, WindowPlacement.minSize.height);
  });
}
