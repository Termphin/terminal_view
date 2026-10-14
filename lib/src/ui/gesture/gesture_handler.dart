import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:terminal_view/src/core/mouse/button.dart';
import 'package:terminal_view/src/core/buffer/cell_offset.dart';
import 'package:terminal_view/src/core/mouse/button_state.dart';
import 'package:terminal_view/src/terminal_view.dart';
import 'package:terminal_view/src/ui/controller.dart';
import 'package:terminal_view/src/ui/gesture/gesture_detector.dart';
import 'package:terminal_view/src/ui/pointer_input.dart';
import 'package:terminal_view/src/ui/render.dart';

class TerminalGestureHandler extends StatefulWidget {
  const TerminalGestureHandler({
    super.key,
    required this.terminalView,
    required this.terminalController,
    required this.scrollController,
    this.onSelectionDragChanged,
    this.child,
    this.onTapUp,
    this.onSingleTapUp,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.readOnly = false,
  });

  final TerminalViewState terminalView;

  final TerminalController terminalController;

  /// Scrolled while a selection drag is held near the top or bottom edge.
  final ScrollController scrollController;

  final ValueChanged<bool>? onSelectionDragChanged;

  final Widget? child;

  final GestureTapUpCallback? onTapUp;

  final GestureTapUpCallback? onSingleTapUp;

  final GestureTapDownCallback? onTapDown;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapUpCallback? onSecondaryTapUp;

  final GestureTapDownCallback? onTertiaryTapDown;

  final GestureTapUpCallback? onTertiaryTapUp;

  final bool readOnly;

  @override
  State<TerminalGestureHandler> createState() => _TerminalGestureHandlerState();
}

class _TerminalGestureHandlerState extends State<TerminalGestureHandler> {
  TerminalViewState get terminalView => widget.terminalView;

  RenderTerminal get renderTerminal => terminalView.renderTerminal;

  static const _edgeScrollInterval = Duration(milliseconds: 60);

  /// The cell a selection drag started on. A cell rather than a position, so
  /// the start of the selection stays on its text while the view scrolls.
  CellOffset? _dragAnchor;

  Offset? _dragPosition;

  bool _dragSelectsWords = false;

  Timer? _edgeScrollTimer;

  /// A view torn down mid-drag never sees the pointer lift, so the drag is
  /// reported over here instead.
  @override
  void dispose() {
    _endSelectionDrag();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detector = TerminalGestureDetector(
      child: widget.child,
      onTapUp: widget.onTapUp,
      onSingleTapUp: onSingleTapUp,
      onTapDown: onTapDown,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapUp: onSecondaryTapUp,
      onTertiaryTapDown: onSecondaryTapDown,
      onTertiaryTapUp: onSecondaryTapUp,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDoubleTapDown: onDoubleTapDown,
    );
    return Listener(
      onPointerUp: (_) => _endSelectionDrag(),
      onPointerCancel: (_) => _endSelectionDrag(),
      child: detector,
    );
  }

  bool get _shouldSendTapEvent =>
      !widget.readOnly &&
      widget.terminalController.shouldSendPointerInput(PointerInput.tap);

  void _tapDown(
    GestureTapDownCallback? callback,
    TapDownDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap down event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.down,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void _tapUp(
    GestureTapUpCallback? callback,
    TapUpDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap up event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.up,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void onTapDown(TapDownDetails details) {
    // onTapDown is special, as it will always call the supplied callback.
    // The TerminalView depends on it to bring the terminal into focus.
    _tapDown(
      widget.onTapDown,
      details,
      TerminalMouseButton.left,
      forceCallback: true,
    );
  }

  void onSingleTapUp(TapUpDetails details) {
    // Also forced, to match onTapDown above: an app that turned on mouse
    // reporting (most full-screen TUIs do) would otherwise swallow every
    // tap as a mouse click, and the terminal would never bring itself into
    // focus - the click still reaches the app either way.
    _tapUp(
      widget.onSingleTapUp,
      details,
      TerminalMouseButton.left,
      forceCallback: true,
    );
  }

  void onSecondaryTapDown(TapDownDetails details) {
    _tapDown(widget.onSecondaryTapDown, details, TerminalMouseButton.right);
  }

  void onSecondaryTapUp(TapUpDetails details) {
    _tapUp(widget.onSecondaryTapUp, details, TerminalMouseButton.right);
  }

  void onTertiaryTapDown(TapDownDetails details) {
    _tapDown(widget.onTertiaryTapDown, details, TerminalMouseButton.middle);
  }

  void onTertiaryTapUp(TapUpDetails details) {
    _tapUp(widget.onTertiaryTapUp, details, TerminalMouseButton.right);
  }

  void onDoubleTapDown(TapDownDetails details) {
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressStart(LongPressStartDetails details) {
    _startSelectionDrag(details.localPosition, words: true);
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _updateSelectionDrag(details.localPosition);
  }

  void onDragStart(DragStartDetails details) {
    _startSelectionDrag(
      details.localPosition,
      words: details.kind != PointerDeviceKind.mouse,
    );
  }

  void onDragUpdate(DragUpdateDetails details) {
    _updateSelectionDrag(details.localPosition);
  }

  void _startSelectionDrag(Offset position, {required bool words}) {
    _dragAnchor = renderTerminal.getCellOffset(position);
    _dragPosition = position;
    _dragSelectsWords = words;
    words
        ? renderTerminal.selectWord(position)
        : renderTerminal.selectCharacters(position);
    widget.onSelectionDragChanged?.call(true);
  }

  void _updateSelectionDrag(Offset position) {
    if (_dragAnchor == null) return;
    _dragPosition = position;
    _extendSelection();
    _edgeScrollTimer ??= Timer.periodic(
      _edgeScrollInterval,
      (_) => _edgeScroll(),
    );
  }

  /// Selects from the center of the anchor cell, wherever the view has
  /// scrolled it to, up to the pointer.
  void _extendSelection() {
    final anchor = _dragAnchor;
    final position = _dragPosition;
    if (anchor == null || position == null) return;
    final cell = renderTerminal.cellSize;
    final from = renderTerminal.getOffset(anchor) +
        Offset(cell.width / 2, cell.height / 2);
    _dragSelectsWords
        ? renderTerminal.selectWord(from, position)
        : renderTerminal.selectCharacters(from, position);
  }

  /// While the pointer is held within one and a half lines of the top or
  /// bottom edge, scroll a line towards it and extend the selection.
  void _edgeScroll() {
    final position = _dragPosition;
    final controller = widget.scrollController;
    if (position == null || !mounted || !controller.hasClients) return;
    final lineHeight = renderTerminal.lineHeight;
    final edge = lineHeight * 1.5;
    final height = renderTerminal.size.height;
    final delta = position.dy < edge
        ? -lineHeight
        : position.dy > height - edge
            ? lineHeight
            : 0.0;
    if (delta == 0) return;
    final scroll = controller.position;
    final target = (scroll.pixels + delta).clamp(
      scroll.minScrollExtent,
      scroll.maxScrollExtent,
    );
    if ((target - scroll.pixels).abs() < 0.5) return;
    controller.jumpTo(target);
    _extendSelection();
  }

  void _endSelectionDrag() {
    _edgeScrollTimer?.cancel();
    _edgeScrollTimer = null;
    _dragPosition = null;
    if (_dragAnchor == null) return;
    _dragAnchor = null;
    widget.onSelectionDragChanged?.call(false);
  }
}
