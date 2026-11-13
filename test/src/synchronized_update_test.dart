import 'package:terminal_view/core.dart';
import 'package:test/test.dart';

void main() {
  group('Synchronized update mode (DEC 2026)', () {
    test('with the mode off, a write notifies listeners', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.write('hello');

      expect(notifyCount, 1);
    });

    test('with the mode on, a write does not notify immediately', () {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.write('\x1b[?2026h');
      expect(notifyCount, 0);

      terminal.write('hello');
      expect(notifyCount, 0);
    });

    test('with the mode on and nothing further written, the listener is notified once the deadline passes', () async {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.write('\x1b[?2026h');
      terminal.write('partial frame');
      expect(notifyCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(notifyCount, 1);
    });

    test('turning the mode off cancels the pending timer: no second, late notification arrives after explicit flush', () async {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.write('\x1b[?2026h');
      terminal.write('hello');
      expect(notifyCount, 0);

      terminal.write('\x1b[?2026l');
      expect(notifyCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(notifyCount, 1);
    });

    test('re-entering the mode while a timer is pending does not leave two timers running', () async {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.write('\x1b[?2026h');
      terminal.write('frame 1');
      terminal.write('\x1b[?2026h');
      terminal.write('frame 2');
      expect(notifyCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(notifyCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(notifyCount, 1);
    });

    test('disposing the terminal cancels the pending timer', () async {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.write('\x1b[?2026h');
      terminal.write('partial frame');
      expect(notifyCount, 0);

      terminal.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(notifyCount, 0);
    });

    test('fullReset cancels the pending timer', () async {
      final terminal = Terminal();
      var notifyCount = 0;
      terminal.addListener(() => notifyCount++);

      terminal.write('\x1b[?2026h');
      terminal.write('partial frame');
      expect(notifyCount, 0);

      terminal.fullReset();

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(notifyCount, 0);
    });
  });
}
