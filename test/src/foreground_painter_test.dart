import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  Future<RenderTerminal> pump(
    WidgetTester tester,
    Terminal terminal,
    TerminalForegroundPainter painter, {
    ScrollController? scroll,
  }) async {
    final key = GlobalKey<TerminalViewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            key: key,
            scrollController: scroll,
            foregroundPainter: painter,
          ),
        ),
      ),
    );
    await tester.pump();
    return key.currentState!.renderTerminal;
  }

  testWidgets('paints the rows in view, where their cells are drawn', (
    tester,
  ) async {
    final terminal = Terminal();
    for (var i = 0; i < 200; i++) {
      terminal.write('line $i\r\n');
    }
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final calls = <(int, int, Offset)>[];
    final render = await pump(
      tester,
      terminal,
      (canvas, origin, render, first, last) => calls.add(
        (first, last, origin + render.getOffset(CellOffset(0, first))),
      ),
      scroll: scroll,
    );

    var (first, last, at) = calls.last;
    expect(last, terminal.buffer.lines.length - 1);
    expect(first, greaterThan(0));
    expect(at.dy, lessThanOrEqualTo(0));

    calls.clear();
    scroll.jumpTo(0);
    await tester.pump();

    (first, last, at) = calls.last;
    expect(first, 0);
    expect(last, lessThan(terminal.buffer.lines.length - 1));
    expect(at, Offset.zero);
    expect(render.getOffset(const CellOffset(0, 0)), Offset.zero);
  });

  testWidgets('a new painter is painted with', (tester) async {
    final terminal = Terminal();
    var painted = 0;
    await pump(tester, terminal, (c, o, r, f, l) {});
    await pump(tester, terminal, (c, o, r, f, l) => painted++);
    expect(painted, greaterThan(0));
  });
}
