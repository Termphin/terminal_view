import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

class _Overlay implements TerminalOverlay {
  @override
  List<TerminalOverlayCell> cells = const [];

  @override
  CellOffset? cursor;

  @override
  bool dimmed = false;
}

TerminalOverlayCell _cell(int row, int column, String char) {
  return TerminalOverlayCell(
    row,
    column,
    CellData(
      foreground: 0,
      background: 0,
      flags: 0,
      content: char.runes.single | (1 << CellContent.widthShift),
    ),
  );
}

void main() {
  group('onAfterWrite', () {
    test('runs after the buffer holds the output and before listeners', () {
      final terminal = Terminal();
      final events = <String>[];
      terminal.onAfterWrite = () {
        events.add('after:${terminal.buffer.lines[0].getText().trim()}');
      };
      terminal.addListener(() => events.add('listener'));

      terminal.write('hi');

      expect(events, ['after:hi', 'listener']);
    });

    test('waits for a synchronized update to end', () {
      final terminal = Terminal();
      var calls = 0;
      terminal.onAfterWrite = () => calls++;

      terminal.write('\x1b[?2026h');
      terminal.write('frame');
      expect(calls, 0);

      terminal.write('\x1b[?2026l');
      expect(calls, 1);
    });
  });

  test('isHoldingFrame follows a synchronized update', () {
    final terminal = Terminal();
    expect(terminal.isHoldingFrame, isFalse);

    terminal.write('\x1b[?2026h');
    expect(terminal.isHoldingFrame, isTrue);

    terminal.write('\x1b[?2026l');
    expect(terminal.isHoldingFrame, isFalse);
  });

  test('setting an overlay notifies listeners', () {
    final terminal = Terminal();
    var notified = 0;
    terminal.addListener(() => notified++);

    final overlay = _Overlay();
    terminal.overlay = overlay;
    terminal.overlay = overlay;

    expect(notified, 1);
  });

  group('RenderTerminal', () {
    Future<RenderTerminal> pump(
      WidgetTester tester,
      Terminal terminal, {
      TerminalStyle textStyle = const TerminalStyle(),
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TerminalView(terminal, textStyle: textStyle)),
        ),
      );
      return tester.renderObject<RenderTerminal>(
        find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_TerminalView'),
      );
    }

    testWidgets('draws the cursor where the overlay puts it', (tester) async {
      final terminal = Terminal();
      final render = await pump(tester, terminal);
      final cell = render.cellSize;
      terminal.write('ab');
      await tester.pump();

      final overlay = _Overlay()
        ..cells = [_cell(0, 2, 'c')]
        ..cursor = const CellOffset(3, 0);
      terminal.overlay = overlay;
      await tester.pump();

      expect(render.cursorOffset.dx, 3 * cell.width);
    });

    testWidgets('fills overlay cells out to whole pixels', (tester) async {
      final terminal = Terminal();
      final render = await pump(
        tester,
        terminal,
        textStyle: const TerminalStyle(fontSize: 13.3),
      );
      final cell = render.cellSize;
      expect(cell.width, isNot(cell.width.roundToDouble()));

      terminal.overlay = _Overlay()..cells = [_cell(0, 3, 'x')];
      await tester.pump();

      final left = 3 * cell.width;
      expect(
        render,
        paints
          ..rect(
            rect: Rect.fromLTRB(
              left.floorToDouble(),
              0,
              (left + cell.width).ceilToDouble(),
              cell.height.ceilToDouble(),
            ),
          ),
      );
    });

    testWidgets('ignores an overlay cursor off the screen', (tester) async {
      final terminal = Terminal();
      final render = await pump(tester, terminal);
      final cell = render.cellSize;
      terminal.write('ab');
      await tester.pump();

      terminal.overlay = _Overlay()
        ..cursor = CellOffset(0, terminal.viewHeight);
      await tester.pump();

      expect(render.cursorOffset.dx, 2 * cell.width);
      expect(tester.takeException(), isNull);
    });
  });
}
