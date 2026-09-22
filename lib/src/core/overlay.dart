import 'package:terminal_view/src/core/buffer/cell_offset.dart';
import 'package:terminal_view/src/core/cell.dart';

/// A cell drawn over the screen in place of what the buffer holds there.
class TerminalOverlayCell {
  const TerminalOverlayCell(this.row, this.column, this.cell);

  /// Row on the visible screen, 0 at the top.
  final int row;

  final int column;

  final CellData cell;
}

/// Content drawn over the screen without touching the buffer, such as a
/// prediction of what the program is about to draw.
///
/// Read on every paint. Call [Terminal.notifyListeners] when it changes
/// between writes, so the view repaints.
abstract class TerminalOverlay {
  /// Cells to draw over the screen, backgrounds included.
  List<TerminalOverlayCell> get cells;

  /// Where to draw the cursor instead of the buffer's own position, as a
  /// column and a row on the visible screen, or null to leave it be.
  CellOffset? get cursor;

  /// Whether [cells] are drawn faded, as not yet certain.
  bool get dimmed;
}
