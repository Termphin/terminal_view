[![Termphin: SSH that survives the dropped connection](https://termphin.dev/og-image.png)](https://termphin.dev)

# terminal_view

A fast terminal emulator widget for Flutter. Feed it bytes from a shell, an SSH
channel or a PTY and it draws a real terminal: VT100/xterm escape sequences,
scrollback, selection, mouse reporting and IME input.

It is the terminal inside [Termphin](https://termphin.dev) and is built for
phones first, but it has no dependency on the app.

## Install

```yaml
dependencies:
  terminal_view: ^0.4.0
```

## Usage

```dart
import 'package:terminal_view/terminal_view.dart';

final terminal = Terminal();

// What the user types. Send it to your shell or SSH channel.
terminal.onOutput = (data) => channel.write(data);

// What the remote side sends back.
terminal.write('Hello, world!\r\n');

Widget build(BuildContext context) => TerminalView(terminal);
```

`Terminal` is the emulator and does not depend on Flutter, so you can test it
or run it in an isolate on its own. `TerminalView` paints it.

### Selection

```dart
final controller = TerminalController();

TerminalView(terminal, controller: controller);

final range = controller.selection;
final text = range == null ? null : terminal.buffer.getText(range);
```

A long press selects a word and a drag extends it. Blank cells can be selected
too.

### Appearance

```dart
TerminalView(
  terminal,
  theme: TerminalThemes.defaultTheme,
  textStyle: const TerminalStyle(fontSize: 14, fontFamily: 'JetBrainsMono'),
  cursorType: TerminalCursorType.block,
)
```

## Example

`example/` runs `TerminalView` against a small shell written in Dart, so it
works anywhere without a PTY:

```bash
cd example && flutter run
```

## Benchmarks

```bash
dart run benchmark/terminal_benchmark.dart
```

This measures parsing and buffer throughput on the plain Dart VM. Painting is
not included.

## Fork of xterm.dart

terminal_view started as a fork of [xterm.dart] 4.0.0. The parser, buffer and
input handling work the same way. The main changes are in rendering:

- Writes are batched once per frame.
- Runs of cells with the same style are drawn together.
- Lines that stop changing are cached and replayed.
- The cursor blinks without rebuilding the widget.

Porting is mostly a matter of changing the import, but the API is not
identical and versions are numbered separately.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

[xterm.dart]: https://github.com/TerminalStudio/xterm.dart
