import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  const settle = Duration(milliseconds: 90);

  late Terminal terminal;
  late ScrollController scroll;
  late ValueNotifier<Size> box;
  late List<(int, int)> resizes;
  final viewKey = GlobalKey<TerminalViewState>();

  setUp(() {
    terminal = Terminal(maxLines: 1000);
    scroll = ScrollController();
    box = ValueNotifier(const Size(400, 600));
    resizes = [];
  });

  tearDown(() {
    scroll.dispose();
    box.dispose();
  });

  Future<void> mount(WidgetTester tester, {Duration delay = settle}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<Size>(
            valueListenable: box,
            builder: (context, size, child) =>
                SizedBox.fromSize(size: size, child: child),
            child: TerminalView(
              terminal,
              key: viewKey,
              scrollController: scroll,
              resizeSettleDelay: delay,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    terminal.onResize = (columns, rows, pixelWidth, pixelHeight) =>
        resizes.add((columns, rows));
  }

  double rowHeight() => viewKey.currentState!.renderTerminal.lineHeight;

  /// Slides the height to [to] over ten frames, the way a keyboard does.
  Future<void> slideHeight(WidgetTester tester, double to) async {
    final from = box.value.height;
    for (var step = 1; step <= 10; step++) {
      box.value = Size(box.value.width, from + (to - from) * step / 10);
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> comeToRest(WidgetTester tester) async {
    await tester.pump(settle);
    await tester.pump();
  }

  testWidgets('a height that keeps moving resizes the terminal once, to '
      'where it stopped', (tester) async {
    await mount(tester);
    final rows = terminal.viewHeight;

    await slideHeight(tester, 300);

    expect(resizes, isEmpty);
    expect(terminal.viewHeight, rows);

    await comeToRest(tester);

    expect(resizes, hasLength(1));
    expect(terminal.viewHeight, (300 / rowHeight()).floor());
  });

  testWidgets('with no delay every frame of it is a resize', (tester) async {
    await mount(tester, delay: Duration.zero);

    await slideHeight(tester, 300);

    expect(resizes.length, greaterThan(5));
  });

  testWidgets('a height that comes back to where it was resizes nothing', (
    tester,
  ) async {
    await mount(tester);

    await slideHeight(tester, 300);
    await slideHeight(tester, 600);
    await comeToRest(tester);

    expect(resizes, isEmpty);
  });

  testWidgets('a change of width is not held back', (tester) async {
    await mount(tester);
    final columns = terminal.viewWidth;

    box.value = const Size(300, 600);
    await tester.pump();

    expect(terminal.viewWidth, lessThan(columns));
    expect(resizes, hasLength(1));
  });

  testWidgets('a width that changes while a height is held back takes both', (
    tester,
  ) async {
    await mount(tester);

    box.value = const Size(400, 400);
    await tester.pump();
    box.value = const Size(300, 400);
    await tester.pump();

    expect(resizes, hasLength(1));
    expect(terminal.viewHeight, (400 / rowHeight()).floor());
    await comeToRest(tester);
    expect(resizes, hasLength(1));
  });

  testWidgets('a prompt at the top of the screen stays put while the height '
      'shrinks over empty rows', (tester) async {
    await mount(tester);
    terminal.write('prompt \$ ');
    await tester.pump();

    await slideHeight(tester, 300);

    expect(scroll.position.pixels, 0);
    await comeToRest(tester);
    expect(scroll.position.pixels, 0);
    expect(terminal.buffer.cursorY, 0);
  });

  testWidgets('a cursor on the last row is kept in view while the height '
      'shrinks, and the rows do not jump when the resize lands', (
    tester,
  ) async {
    await mount(tester);
    final rows = terminal.viewHeight;
    for (var row = 0; row < rows - 1; row++) {
      terminal.write('line $row\r\n');
    }
    terminal.write('prompt \$ ');
    await tester.pump();
    expect(scroll.position.pixels, 0);

    await slideHeight(tester, 300);

    final newRows = (300 / rowHeight()).floor();
    final held = scroll.position.pixels;
    expect(held, closeTo((rows - newRows) * rowHeight(), rowHeight()));
    expect(held, greaterThan(0));

    await comeToRest(tester);

    expect(terminal.viewHeight, newRows);
    expect(scroll.position.pixels, held);
    expect(terminal.buffer.cursorY, newRows - 1);
  });

  testWidgets('growing back brings rows from the scrollback without a jump', (
    tester,
  ) async {
    box.value = const Size(400, 300);
    await mount(tester);
    for (var row = 0; row < 200; row++) {
      terminal.write('line $row\r\n');
    }
    await tester.pump();
    final lines = terminal.buffer.lines.length;

    await slideHeight(tester, 600);

    final newRows = (600 / rowHeight()).floor();
    final held = scroll.position.pixels;
    expect(held, closeTo((lines - newRows) * rowHeight(), rowHeight()));

    await comeToRest(tester);

    expect(terminal.viewHeight, newRows);
    expect(scroll.position.pixels, held);
  });
}
