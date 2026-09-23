import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  testWidgets(
    'scroll still reaches the application after an ancestor theme changes',
    (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[?1049h\x1b[?1000h\x1b[?1006h');

      Widget app(Color seed) => MaterialApp(
            theme: ThemeData(colorSchemeSeed: seed),
            home: Scaffold(body: TerminalView(terminal)),
          );

      await tester.pumpWidget(app(Colors.blue));
      await tester.pumpWidget(app(Colors.red));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(TerminalView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(output.join(), contains('\x1b[<65;'));
    },
  );
}
