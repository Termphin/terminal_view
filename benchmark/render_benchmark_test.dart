/// Frame cost of the view, measured on the host: how long one `pump` takes -
/// build, layout and paint, which is the display list being recorded, not
/// rasterised. Run with `flutter test benchmark/render_benchmark_test.dart`.
///
/// It runs under the JIT with the test font, so the numbers mean nothing on
/// their own; they are for comparing one build of the view against another.
/// What the GPU makes of the recorded frame only a device can tell.
@Tags(['benchmark'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

const _columns = 58;
const _rows = 44;
const _warmup = 30;
const _frames = 240;

final _results = <String, List<int>>{};

void main() {
  tearDownAll(() {
    final out = StringBuffer('\nscenario'.padRight(36))
      ..writeln('median µs'.padLeft(10) + 'p95 µs'.padLeft(10));
    for (final MapEntry(key: name, value: samples) in _results.entries) {
      samples.sort();
      final median = samples[samples.length ~/ 2];
      final p95 = samples[(samples.length * 0.95).floor()];
      out.writeln(
        name.padRight(35) + '$median'.padLeft(10) + '$p95'.padLeft(10),
      );
    }
    stdout.writeln(out);
  });

  _scenario('idle, cursor blinking', frame: (bench, i) {
    bench.terminal.notifyListeners();
  });

  _scenario('one line redrawn (spinner)', frame: (bench, i) {
    const frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    bench.terminal.write(
      '\r\x1b[2K\x1b[38;5;208m${frames[i % 10]}\x1b[39m Thinking… '
      '(${i ~/ 10}s · esc to interrupt)',
    );
  });

  _scenario('two new lines a frame (streaming)', frame: (bench, i) {
    bench.terminal.write('${_prose(i * 2)}\r\n${_prose(i * 2 + 1)}\r\n');
  });

  _scenario('whole screen rewritten', frame: (bench, i) {
    final frame = StringBuffer('\x1b[H');
    for (var row = 0; row < _rows - 1; row++) {
      frame.write('\x1b[2K${_prose(i * 7 + row)}\r\n');
    }
    bench.terminal.write(frame.toString());
  });

  _scenario('scrolling back through history', frame: (bench, i) {
    final position = bench.scroll.position;
    final target = position.maxScrollExtent - (i + 1) * 37.0;
    bench.scroll.jumpTo(target.clamp(0, position.maxScrollExtent));
  });

  _scenario('keyboard sliding in and out', frame: (bench, i) {
    final phase = i % 40;
    final travel = phase < 20 ? phase : 40 - phase;
    bench.height.value = 800 - travel * 16.0;
  });
}

void _scenario(
  String name, {
  required void Function(_Bench bench, int frame) frame,
}) {
  _variant(name, frame: frame, glyphAtlas: false, settle: Duration.zero);
  _variant(
    '$name +',
    frame: frame,
    glyphAtlas: true,
    settle: const Duration(milliseconds: 90),
  );
}

/// One scenario as the view comes ([glyphAtlas] off, no [settle]) or, marked
/// `+`, with glyphs stamped from an atlas and resizes held until the height
/// rests.
void _variant(
  String name, {
  required void Function(_Bench bench, int frame) frame,
  required bool glyphAtlas,
  required Duration settle,
}) {
  testWidgets(name, (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(1233, 2400);
    addTearDown(tester.view.reset);

    final bench = _Bench();
    for (var line = 0; line < 6000; line++) {
      bench.terminal.write('${_prose(line)}\r\n');
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder<double>(
            valueListenable: bench.height,
            builder: (context, height, child) =>
                SizedBox(width: 411, height: height, child: child),
            child: TerminalView(
              bench.terminal,
              scrollController: bench.scroll,
              textStyle: const TerminalStyle(fontSize: 12),
              blinkInterval: const Duration(milliseconds: 600),
              glyphAtlas: glyphAtlas,
              resizeSettleDelay: settle,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final clock = Stopwatch();
    final samples = <int>[];
    for (var i = 0; i < _warmup + _frames; i++) {
      frame(bench, i);
      clock
        ..reset()
        ..start();
      await tester.pump(const Duration(milliseconds: 8));
      clock.stop();
      if (i >= _warmup) samples.add(clock.elapsedMicroseconds);
    }
    _results[name] = samples;

    await tester.pumpWidget(const SizedBox());
    bench.dispose();
  });
}

class _Bench {
  final terminal = Terminal(maxLines: 10000)..resize(_columns, _rows);
  final scroll = ScrollController();
  final height = ValueNotifier<double>(800);

  void dispose() {
    scroll.dispose();
    height.dispose();
    terminal.dispose();
  }
}

const _words = [
  'the',
  'terminal',
  'renders',
  'every',
  'frame',
  'with',
  'styled',
  'runs',
  'const',
  'final',
  'return',
  'await',
  'import',
  'class',
  'void',
  'async',
  '│',
  '├──',
  '└──',
  '●',
  '✓',
  '→',
  'zażółć',
  'gęślą',
  '0x1f',
  '42',
  '{}',
];

/// A line of prose and code in several colours, the same for the same [seed].
String _prose(int seed) {
  final random = Random(seed);
  final line = StringBuffer();
  var width = 0;
  while (true) {
    final word = _words[random.nextInt(_words.length)];
    if (width + word.length + 1 >= _columns) break;
    final styled = random.nextInt(3) == 0;
    if (styled) {
      line.write('\x1b[${random.nextBool() ? '1;' : ''}38;5;'
          '${random.nextInt(200) + 20}m');
    }
    line.write(word);
    if (styled) line.write('\x1b[0m');
    line.write(' ');
    width += word.length + 1;
  }
  return line.toString();
}
