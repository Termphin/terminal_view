import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _kDefaultFontSize = 13.0;

const _kDefaultHeight = 1.0;

const _kDefaultFontFamily = 'Roboto Mono';

const _kDefaultFontFamilyFallback = [
  'Roboto Mono',
  'Menlo',
  'Monaco',
  'Consolas',
  'Liberation Mono',
  'Courier New',
  'Noto Sans Mono CJK SC',
  'Noto Sans Mono CJK TC',
  'Noto Sans Mono CJK KR',
  'Noto Sans Mono CJK JP',
  'Noto Sans Mono CJK HK',
  'Noto Color Emoji',
  'Noto Sans Symbols',
  'monospace',
  'sans-serif',
];

// Ligatures merge sequences like -> != => into wider glyphs, breaking column
// alignment.
const _kDefaultFontFeatures = [
  FontFeature.disable('liga'),
  FontFeature.disable('calt'),
];

class TerminalStyle {
  const TerminalStyle({
    this.fontSize = _kDefaultFontSize,
    this.height = _kDefaultHeight,
    this.fontFamily = _kDefaultFontFamily,
    this.fontFamilyFallback = _kDefaultFontFamilyFallback,
    this.fontFeatures = _kDefaultFontFeatures,
  });

  factory TerminalStyle.fromTextStyle(TextStyle textStyle) {
    return TerminalStyle(
      fontSize: textStyle.fontSize ?? _kDefaultFontSize,
      height: textStyle.height ?? _kDefaultHeight,
      fontFamily: textStyle.fontFamily ??
          textStyle.fontFamilyFallback?.first ??
          _kDefaultFontFamily,
      fontFamilyFallback:
          textStyle.fontFamilyFallback ?? _kDefaultFontFamilyFallback,
      fontFeatures: textStyle.fontFeatures ?? _kDefaultFontFeatures,
    );
  }

  final double fontSize;

  final double height;

  final String fontFamily;

  final List<String> fontFamilyFallback;

  final List<FontFeature> fontFeatures;

  /// Underlines are never rendered: [CellFlags.underline] is ignored and the
  /// style always resolves to [TextDecoration.none].
  TextStyle toTextStyle({
    Color? color,
    Color? backgroundColor,
    bool bold = false,
    bool italic = false,
  }) {
    return TextStyle(
      fontSize: fontSize,
      height: height,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontFeatures: fontFeatures,
      color: color,
      backgroundColor: backgroundColor,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: TextDecoration.none,
    );
  }

  TerminalStyle copyWith({
    double? fontSize,
    double? height,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    List<FontFeature>? fontFeatures,
  }) {
    return TerminalStyle(
      fontSize: fontSize ?? this.fontSize,
      height: height ?? this.height,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      fontFeatures: fontFeatures ?? this.fontFeatures,
    );
  }

  // As with [TerminalTheme]: a new style re-measures the cell size and flushes
  // the paragraph cache.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TerminalStyle &&
        other.fontSize == fontSize &&
        other.height == height &&
        other.fontFamily == fontFamily &&
        listEquals(other.fontFamilyFallback, fontFamilyFallback) &&
        listEquals(other.fontFeatures, fontFeatures);
  }

  @override
  int get hashCode => Object.hash(
        fontSize,
        height,
        fontFamily,
        Object.hashAll(fontFamilyFallback),
        Object.hashAll(fontFeatures),
      );
}
