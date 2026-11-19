import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:terminal_view/terminal_view.dart';

/// The middle button had been wired to the secondary handlers, so a middle
/// click opened whatever the right button opens - an app's context menu -
/// and a program with mouse reporting on heard a right click.
void main() {
  Future<(List<String>, List<String>)> pump(WidgetTester tester) async {
    final calls = <String>[];
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            onSecondaryTapDown: (_, _) => calls.add('secondary'),
            onTertiaryTapDown: (_, _) => calls.add('tertiary'),
          ),
        ),
      ),
    );
    return (calls, output);
  }

  testWidgets('a middle click is a middle click, not a right one', (
    tester,
  ) async {
    final (calls, _) = await pump(tester);

    await tester.tapAt(
      tester.getCenter(find.byType(TerminalView)),
      buttons: kTertiaryButton,
    );
    await tester.pumpAndSettle();

    expect(calls, ['tertiary']);
  });

  testWidgets('a right click still reaches the secondary handler', (
    tester,
  ) async {
    final (calls, _) = await pump(tester);

    await tester.tapAt(
      tester.getCenter(find.byType(TerminalView)),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(calls, ['secondary']);
  });

  testWidgets('a program with mouse reporting hears the middle button', (
    tester,
  ) async {
    final (_, output) = await pump(tester);
    final terminal = tester
        .widget<TerminalView>(find.byType(TerminalView))
        .terminal;
    terminal.write('\x1b[?1000h\x1b[?1006h');
    await tester.pump();

    await tester.tapAt(
      tester.getCenter(find.byType(TerminalView)),
      buttons: kTertiaryButton,
    );
    await tester.pumpAndSettle();

    expect(output.join(), allOf(contains('\x1b[<1;'), contains('M')));
    expect(output.join(), isNot(contains('\x1b[<2;')));
  });
}
