import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

/// Select all used to stretch to the last row of the screen, so a copy of a
/// short session came with a screenful of blank lines after it.
void main() {
  test('select all ends at the last line with text', () {
    final terminal = Terminal();
    terminal.resize(40, 10);
    terminal.write('first line\r\nsecond');
    final controller = TerminalController();

    controller.selectAll(terminal.buffer);

    expect(terminal.buffer.getText(controller.selection), 'first line\nsecond');
  });

  test('select all takes the scrollback too', () {
    final terminal = Terminal();
    terminal.resize(40, 3);
    for (var i = 0; i < 6; i++) {
      terminal.write('line $i\r\n');
    }
    final controller = TerminalController();

    controller.selectAll(terminal.buffer);

    expect(terminal.buffer.getText(controller.selection), startsWith('line 0'));
    expect(terminal.buffer.getText(controller.selection), endsWith('line 5'));
  });
}
