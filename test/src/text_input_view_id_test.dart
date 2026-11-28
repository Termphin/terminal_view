import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  testWidgets(
    'the text input client names its view, which Windows requires before '
    'it sends any typed character',
    (tester) async {
      final clients = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          if (call.method == 'TextInput.setClient') {
            final args = call.arguments as List<Object?>;
            clients.add(args[1]! as Map<Object?, Object?>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: TerminalView(Terminal()))),
      );
      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();

      expect(clients, isNotEmpty);
      expect(clients.last['viewId'], tester.view.viewId);
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
