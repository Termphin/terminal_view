import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:terminal_view/src/ui/terminal_text_style.dart';

/// Printable ASCII in the terminal's font, drawn once into an image and
/// stamped out of it from then on.
///
/// Text otherwise goes through a paragraph per run of one style. A paragraph
/// is found again only when the same words come back in the same style -
/// true of a prompt, almost never of prose streaming past - so each new line
/// lays its runs out from scratch, and each run is a draw of its own. A glyph
/// is the same picture wherever it stands. Ninety-four of them in four
/// styles cover nearly everything a terminal shows, a line of them is one
/// draw whatever its colours, and nothing is laid out after the first frame.
///
/// The glyphs are drawn white and take their colour when stamped. They are
/// drawn at the device's pixels, so a stamp is a copy and not a scaling, and
/// each sits in a slot wider and taller than a cell: an italic leans out of
/// its cell and a descender can reach below it.
///
/// One page per style, made the first time a glyph in that style is wanted.
class GlyphAtlas {
  GlyphAtlas({
    required this.textStyle,
    required this.textScaler,
    required this.cellSize,
    required this.devicePixelRatio,
  }) {
    final cellWidth = cellSize.width * devicePixelRatio;
    final cellHeight = cellSize.height * devicePixelRatio;
    _padX = (cellWidth * 0.35).ceil() + 1;
    _padY = (cellHeight * 0.2).ceil() + 1;
    _slotWidth = cellWidth.ceil() + _padX * 2;
    _slotHeight = cellHeight.ceil() + _padY * 2;
  }

  /// The first and one past the last code point held. A space has no glyph.
  static const first = 0x21;
  static const end = 0x7f;

  static const styleCount = 4;
  static const _columns = 16;
  static const _rows = (end - first + _columns - 1) ~/ _columns;

  final TerminalStyle textStyle;
  final TextScaler textScaler;
  final Size cellSize;
  final double devicePixelRatio;

  late final int _padX;
  late final int _padY;
  late final int _slotWidth;
  late final int _slotHeight;

  final _pages = List<Image?>.filled(styleCount, null);

  /// Which page a cell's attributes pick.
  static int styleOf({required bool bold, required bool italic}) =>
      (bold ? 1 : 0) | (italic ? 2 : 0);

  static bool holds(int codePoint) => codePoint >= first && codePoint < end;

  /// How far left of and above a cell's corner its stamp starts, in logical
  /// pixels.
  double get originX => _padX / devicePixelRatio;
  double get originY => _padY / devicePixelRatio;

  Image page(int style) => _pages[style] ??= _draw(style);

  /// Writes where [codePoint] sits in a page into [rects] at [at], as
  /// `drawRawAtlas` wants it: left, top, right, bottom.
  @pragma('vm:prefer-inline')
  void writeRect(int codePoint, Float32List rects, int at) {
    final slot = codePoint - first;
    final left = (slot % _columns) * _slotWidth;
    final top = (slot ~/ _columns) * _slotHeight;
    rects[at] = left.toDouble();
    rects[at + 1] = top.toDouble();
    rects[at + 2] = (left + _slotWidth).toDouble();
    rects[at + 3] = (top + _slotHeight).toDouble();
  }

  Image _draw(int style) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)..scale(devicePixelRatio);

    final glyphStyle = textStyle.toTextStyle(
      color: const Color(0xFFFFFFFF),
      bold: style & 1 != 0,
      italic: style & 2 != 0,
    );
    final paragraphStyle = glyphStyle.getParagraphStyle(
      strutStyle: textStyle.toStrutStyle(),
      textScaler: textScaler,
    );
    final uiStyle = glyphStyle.getTextStyle(textScaler: textScaler);

    for (var codePoint = first; codePoint < end; codePoint++) {
      final slot = codePoint - first;
      final builder = ParagraphBuilder(paragraphStyle)
        ..pushStyle(uiStyle)
        ..addText(String.fromCharCode(codePoint));
      final paragraph = builder.build()
        ..layout(const ParagraphConstraints(width: double.infinity));
      canvas.drawParagraph(
        paragraph,
        Offset(
          ((slot % _columns) * _slotWidth + _padX) / devicePixelRatio,
          ((slot ~/ _columns) * _slotHeight + _padY) / devicePixelRatio,
        ),
      );
      paragraph.dispose();
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      _columns * _slotWidth,
      _rows * _slotHeight,
    );
    picture.dispose();
    return image;
  }

  void dispose() {
    for (var style = 0; style < styleCount; style++) {
      _pages[style]?.dispose();
      _pages[style] = null;
    }
  }
}

/// The stamps of one line in one style, gathered so they go out as one draw.
class GlyphBatch {
  var _transforms = Float32List(4 * 128);
  var _rects = Float32List(4 * 128);
  var _colors = Int32List(128);
  var _count = 0;

  bool get isEmpty => _count == 0;

  /// Adds [codePoint] with its slot's corner at [x], [y], [scale] logical
  /// pixels to an atlas pixel.
  @pragma('vm:prefer-inline')
  void add(
    GlyphAtlas atlas,
    int codePoint,
    double x,
    double y,
    double scale,
    int color,
  ) {
    if (_count == _colors.length) _grow();
    final at = _count * 4;
    _transforms[at] = scale;
    _transforms[at + 1] = 0;
    _transforms[at + 2] = x;
    _transforms[at + 3] = y;
    atlas.writeRect(codePoint, _rects, at);
    _colors[_count] = color;
    _count++;
  }

  void _grow() {
    final size = _colors.length * 2;
    _transforms = Float32List(size * 4)..setAll(0, _transforms);
    _rects = Float32List(size * 4)..setAll(0, _rects);
    _colors = Int32List(size)..setAll(0, _colors);
  }

  /// Draws what was gathered from [page] and empties the batch.
  ///
  /// The glyphs are white, so multiplying by the colour gives the colour at
  /// the glyph's coverage. Multiplication is also the one way of combining
  /// the two that reads the same whichever of them a renderer takes to be
  /// the source.
  void flush(Canvas canvas, Image page, Paint paint) {
    if (_count == 0) return;
    canvas.drawRawAtlas(
      page,
      Float32List.sublistView(_transforms, 0, _count * 4),
      Float32List.sublistView(_rects, 0, _count * 4),
      Int32List.sublistView(_colors, 0, _count),
      BlendMode.modulate,
      null,
      paint,
    );
    _count = 0;
  }
}
