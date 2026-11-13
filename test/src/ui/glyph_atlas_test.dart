import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  const screen = [
    'plain text and \x1b[1mbold\x1b[0m and \x1b[3mitalic\x1b[0m',
    '\x1b[31mred \x1b[32mgreen \x1b[38;5;208morange \x1b[38;2;10;200;250mrgb\x1b[0m',
    '\x1b[7minverse\x1b[0m \x1b[2mfaint\x1b[0m \x1b[1;3;34mbold italic\x1b[0m',
    '\x1b[44mon blue\x1b[0m \x1b[9mstruck\x1b[0m \x1b[8mhidden\x1b[0m end',
    'symbols │├──└ ●✓→ zażółć gęślą 日本 after',
    r'~!@#$%^&*()_+{}|:"<>?`-=[]\;,./ 0123456789',
  ];

  /// The terminal showing [screen], as pixels.
  Future<ByteData> render(
    WidgetTester tester, {
    required bool glyphAtlas,
    required double devicePixelRatio,
  }) async {
    tester.view
      ..devicePixelRatio = devicePixelRatio
      ..physicalSize = Size(400 * devicePixelRatio, 200 * devicePixelRatio);
    addTearDown(tester.view.reset);

    final terminal = Terminal()..write(screen.join('\r\n'));
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundary,
          child: TerminalView(
            terminal,
            key: ValueKey(glyphAtlas),
            glyphAtlas: glyphAtlas,
            textStyle: const TerminalStyle(fontSize: 12),
          ),
        ),
      ),
    );
    await tester.pump();

    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: devicePixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    });
    await tester.pumpWidget(const SizedBox());
    return bytes!;
  }

  /// The share of pixels where [a] and [b] differ by more than rounding.
  double differing(ByteData a, ByteData b) {
    expect(a.lengthInBytes, b.lengthInBytes);
    var different = 0;
    for (var at = 0; at < a.lengthInBytes; at += 4) {
      for (var channel = 0; channel < 3; channel++) {
        if ((a.getUint8(at + channel) - b.getUint8(at + channel)).abs() > 32) {
          different++;
          break;
        }
      }
    }
    return different / (a.lengthInBytes / 4);
  }

  int lit(ByteData pixels) {
    var count = 0;
    for (var at = 0; at < pixels.lengthInBytes; at += 4) {
      if (pixels.getUint8(at) +
              pixels.getUint8(at + 1) +
              pixels.getUint8(at + 2) >
          96) {
        count++;
      }
    }
    return count;
  }

  testWidgets(
      'stamped glyphs put the same pixels on the screen as text laid '
      'out', (tester) async {
    final laidOut = await render(
      tester,
      glyphAtlas: false,
      devicePixelRatio: 3,
    );
    final stamped = await render(
      tester,
      glyphAtlas: true,
      devicePixelRatio: 3,
    );

    expect(lit(laidOut), greaterThan(5000), reason: 'nothing was drawn');
    expect(differing(laidOut, stamped), lessThan(0.004));
  });

  testWidgets(
      'and stay within a pixel of it where a pixel is not a whole '
      'number of logical ones', (tester) async {
    final laidOut = await render(
      tester,
      glyphAtlas: false,
      devicePixelRatio: 2.625,
    );
    final stamped = await render(
      tester,
      glyphAtlas: true,
      devicePixelRatio: 2.625,
    );

    expect(differing(laidOut, stamped), lessThan(0.05));
    expect(lit(stamped), closeTo(lit(laidOut), lit(laidOut) * 0.05));
  });

  testWidgets(
      'switching a view that is already showing lines redraws them the '
      'other way, both ways', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(1200, 600);
    addTearDown(tester.view.reset);
    final terminal = Terminal()..write(screen.join('\r\n'));
    final boundary = GlobalKey();
    final atlas = ValueNotifier(false);
    addTearDown(atlas.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundary,
          child: ValueListenableBuilder<bool>(
            valueListenable: atlas,
            builder: (context, on, child) => TerminalView(
              terminal,
              glyphAtlas: on,
              textStyle: const TerminalStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );

    Future<ByteData> settled() async {
      for (var frame = 0; frame < 3; frame++) {
        terminal.notifyListeners();
        await tester.pump();
      }
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!;
      }))!;
    }

    final laidOut = await settled();
    atlas.value = true;
    final stamped = await settled();
    atlas.value = false;
    final laidOutAgain = await settled();
    atlas.value = true;
    final stampedAgain = await settled();

    expect(differing(laidOut, stamped), lessThan(0.004));
    expect(differing(laidOut, laidOutAgain), 0);
    expect(differing(stamped, stampedAgain), 0);
  });

  testWidgets(
      'a line that held still is replayed from its recording and '
      'still reads the same', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(1200, 600);
    addTearDown(tester.view.reset);
    final terminal = Terminal()..write(screen.join('\r\n'));
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundary,
          child: TerminalView(
            terminal,
            glyphAtlas: true,
            textStyle: const TerminalStyle(fontSize: 12),
          ),
        ),
      ),
    );

    Future<ByteData> capture() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!;
      }))!;
    }

    await tester.pump();
    final first = await capture();
    for (var frame = 0; frame < 3; frame++) {
      terminal.notifyListeners();
      await tester.pump();
    }
    final replayed = await capture();

    expect(differing(first, replayed), 0);
  });
}
