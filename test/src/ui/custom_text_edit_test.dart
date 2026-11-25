import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

/// Typing faster than the platform applies the editing state the terminal
/// resets after each insert: the next update still carries the text that was
/// already sent. Seen on a Linux desktop at 30-70 ms between keys, where
/// `abcdef` reached the shell as `abbcbcdef`.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> focusedTerminal(
    WidgetTester tester, {
    bool deleteDetection = false,
  }) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            autofocus: true,
            deleteDetection: deleteDetection,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(seconds: 1));
    return output;
  }

  void engineSends(String text) {
    binding.testTextInput.updateEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  testWidgets('sends each key once while the reset is still on its way', (
    tester,
  ) async {
    final output = await focusedTerminal(tester);

    engineSends('a');
    engineSends('ab');
    engineSends('abc');
    await binding.idle();

    expect(output.join(), 'abc');
  });

  testWidgets('takes the next update from the reset state once it lands', (
    tester,
  ) async {
    final output = await focusedTerminal(tester);

    engineSends('a');
    engineSends('ab');
    engineSends('c');
    engineSends('cd');
    await binding.idle();

    expect(output.join(), 'abcd');
  });

  testWidgets('sends the same key again when it is typed again', (
    tester,
  ) async {
    final output = await focusedTerminal(tester);

    engineSends('a');
    engineSends('a');
    engineSends('a');
    await binding.idle();

    expect(output.join(), 'aaa');
  });

  testWidgets('keeps the delete-detection prefix out of what is sent', (
    tester,
  ) async {
    final output = await focusedTerminal(tester, deleteDetection: true);

    engineSends('  x');
    engineSends('  xy');
    engineSends('  z');
    await binding.idle();

    expect(output.join(), 'xyz');
  });

  testWidgets(
    'does not insert a space when the reset state echoes after a delete',
    (tester) async {
      final output = await focusedTerminal(tester, deleteDetection: true);

      engineSends('  a');
      engineSends('  ');
      engineSends('  b');
      engineSends('  ');
      engineSends(' ');
      engineSends('  ');
      engineSends(' ');
      engineSends('  ');
      engineSends(' ');
      engineSends('  ');
      engineSends('  c');
      await binding.idle();

      expect(output, ['a', 'b', '\x7f', '\x7f', '\x7f', 'c']);
    },
  );

  testWidgets(
    'does not prepend a space to the next insert after a delete without reset echo',
    (tester) async {
      final output = await focusedTerminal(tester, deleteDetection: true);

      engineSends('  a');
      engineSends(' ');
      engineSends('  c');
      await binding.idle();

      expect(output, ['a', '\x7f', 'c']);
    },
  );

  testWidgets('handles rapid deletes before the reset lands', (tester) async {
    final output = await focusedTerminal(tester, deleteDetection: true);

    engineSends(' ');
    engineSends('');
    engineSends('  ');
    engineSends('  x');
    await binding.idle();

    expect(output, ['\x7f', '\x7f', 'x']);
  });
}
