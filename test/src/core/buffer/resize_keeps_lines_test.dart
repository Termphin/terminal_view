import 'package:test/test.dart';
import 'package:terminal_view/src/terminal.dart';

String all(Terminal t) {
  final lines = <String>[];
  for (var i = 0; i < t.buffer.lines.length; i++) {
    final line = t.buffer.lines[i];
    if (line.isWrapped && lines.isNotEmpty) {
      lines[lines.length - 1] = lines.last + line.toString();
    } else {
      lines.add(line.toString());
    }
  }
  return lines.map((l) => l.trimRight()).where((l) => l.isNotEmpty).join('\n');
}

void main() {
  final paragraph = List.generate(
    30,
    (i) => 'line $i ${'word ' * (i % 7 + 3)}',
  ).join('\r\n');

  test('a width change keeps every line, with the cursor at the bottom', () {
    final t = Terminal(maxLines: 1000);
    t.resize(40, 20);
    t.write('$paragraph\r\n');
    final before = all(t);
    for (final w in [30, 52, 25, 40]) {
      t.resize(w, 20);
    }
    expect(all(t), before);
  });

  test('a shorter screen keeps the lines under a cursor near the bottom, '
      'as when a keyboard opens over an input box', () {
    final t = Terminal(maxLines: 1000);
    t.resize(40, 20);
    t.write('$paragraph\r\n');
    t.write('\x1b[15;1H');
    final before = all(t);
    t.resize(40, 10);
    t.resize(40, 20);
    expect(all(t), before);
  });

  test('a width change keeps every line, with the cursor up high', () {
    final t = Terminal(maxLines: 1000);
    t.resize(40, 20);
    t.write('$paragraph\r\n');
    t.write('\x1b[5;1H');
    final before = all(t);
    t.resize(30, 20);
    t.resize(40, 20);
    expect(all(t), before);
  });

  test('a screen too short for everything under the cursor keeps the cursor '
      'on it', () {
    final t = Terminal(maxLines: 1000);
    t.resize(40, 20);
    t.write('$paragraph\r\n');
    t.write('\x1b[2;1H');
    t.resize(40, 5);
    expect(t.buffer.cursorY, inInclusiveRange(0, 4));
  });
}
