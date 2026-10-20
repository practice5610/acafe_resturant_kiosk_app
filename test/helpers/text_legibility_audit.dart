import 'dart:io';

import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// One painted text run that fails a legibility rule.
class LegibilityIssue {
  final String text;
  final String problem;

  const LegibilityIssue(this.text, this.problem);

  @override
  String toString() => '"$text": $problem';
}

/// Font families registered in `pubspec.yaml`, with the weights each one
/// actually ships. Parsed once per test run.
Map<String, Set<int>> get registeredFontFamilies =>
    _registeredFontFamilies ??= _parsePubspecFonts(
      File('pubspec.yaml').readAsStringSync(),
    );
Map<String, Set<int>>? _registeredFontFamilies;

Map<String, Set<int>> _parsePubspecFonts(String yaml) {
  final Map<String, List<int>> faces = {};
  List<int>? current;
  for (final String raw in yaml.split('\n')) {
    final String line = raw.trim();
    final RegExpMatch? family = RegExp(r'^- family:\s*(\S+)').firstMatch(line);
    if (family != null) {
      current = faces.putIfAbsent(family.group(1)!, () => <int>[]);
      continue;
    }
    if (current == null) continue;
    // A face is Regular unless a `weight:` line follows its asset.
    if (line.startsWith('- asset:')) current.add(400);
    final RegExpMatch? weight = RegExp(r'^weight:\s*(\d+)').firstMatch(line);
    if (weight != null && current.isNotEmpty) {
      current[current.length - 1] = int.parse(weight.group(1)!);
    }
  }
  return {
    for (final MapEntry<String, List<int>> e in faces.entries)
      e.key: e.value.toSet(),
  };
}

/// Icon glyph fonts render through [RichText] too; they are not copy.
bool _isIconFont(String family) =>
    family == 'MaterialIcons' ||
    family == 'CupertinoIcons' ||
    family.startsWith('packages/');

/// Audits every [RichText] under [within] (default: the whole tree) for:
///
/// * **Contrast**: the run's colour, with any [Opacity] / [FadeTransition]
///   ancestors applied, against the nearest painted surface behind it,
///   composited the way the screen shows it. The floor is
///   [TextLegibility.requiredContrast] for the run's size and weight, unless
///   [minRatio] overrides it.
/// * **Font family**: a `fontFamily` that `pubspec.yaml` does not register
///   silently falls back to another face.
/// * **Synthesised bold**: a weight of 600+ on a family with no face that
///   heavy is faked by the renderer and smears at small sizes.
///
/// The surface is found by walking up the element tree through [ColoredBox],
/// [DecoratedBox], [Ink], [Material] and [Scaffold]. A background painted by
/// a *sibling* (a [Stack] layer behind the text) is not an ancestor. Mount
/// such widgets on a [ColoredBox] of the real surface, or pass
/// [defaultBackground].
///
/// [ignore] skips runs on purpose, e.g. a disabled control's label, which
/// WCAG 1.4.3 exempts.
List<LegibilityIssue> auditTextLegibility(
  WidgetTester tester, {
  Finder? within,
  Color defaultBackground = Colors.white,
  double? minRatio,
  bool Function(String text)? ignore,
}) {
  final Finder texts = within == null
      ? find.byType(RichText)
      : find.descendant(of: within, matching: find.byType(RichText));
  final List<LegibilityIssue> issues = [];

  for (final Element element in texts.evaluate()) {
    final RenderObject? render = element.renderObject;
    if (render is! RenderParagraph) continue;
    final _Backdrop backdrop = _backdropOf(element, defaultBackground);

    void visit(InlineSpan span, TextStyle? inherited) {
      final TextStyle? style =
          inherited == null ? span.style : inherited.merge(span.style);
      if (span is TextSpan) {
        final String text = span.text?.trim() ?? '';
        if (text.isNotEmpty && !(ignore?.call(text) ?? false)) {
          issues.addAll(_checkRun(text, style, backdrop, minRatio));
        }
        for (final InlineSpan child in span.children ?? const []) {
          visit(child, style);
        }
      }
    }

    visit(render.text, null);
  }
  return issues;
}

/// Fails the test with every issue [auditTextLegibility] finds.
void expectLegibleText(
  WidgetTester tester, {
  Finder? within,
  Color defaultBackground = Colors.white,
  double? minRatio,
  bool Function(String text)? ignore,
}) {
  final List<LegibilityIssue> issues = auditTextLegibility(
    tester,
    within: within,
    defaultBackground: defaultBackground,
    minRatio: minRatio,
    ignore: ignore,
  );
  expect(issues, isEmpty, reason: issues.join('\n'));
}

List<LegibilityIssue> _checkRun(
  String text,
  TextStyle? style,
  _Backdrop backdrop,
  double? minRatio,
) {
  final String? family = style?.fontFamily;
  if (family != null && _isIconFont(family)) return const [];

  final List<LegibilityIssue> issues = [];
  final double size = style?.fontSize ?? 14;
  final FontWeight weight = style?.fontWeight ?? FontWeight.w400;

  final Color painted =
      style?.color ?? style?.foreground?.color ?? const Color(0xFF000000);
  final Color shown = painted.withValues(alpha: painted.a * backdrop.opacity);
  final double ratio = TextLegibility.contrastRatio(shown, backdrop.surface);
  final double floor =
      minRatio ?? TextLegibility.requiredContrast(size, weight);
  if (ratio < floor) {
    issues.add(LegibilityIssue(
      text,
      'contrast ${ratio.toStringAsFixed(2)}:1 < ${floor.toStringAsFixed(1)}:1 '
      '(${_hex(shown)} on ${_hex(backdrop.surface)}, '
      '${size.toStringAsFixed(1)}px w${weight.value})',
    ));
  }

  if (family != null) {
    final Set<int>? weights = registeredFontFamilies[family];
    if (weights == null) {
      issues.add(LegibilityIssue(
        text,
        'fontFamily "$family" is not registered in pubspec.yaml',
      ));
    } else if (weight.value >= 600 && weights.every((int w) => w < 600)) {
      issues.add(LegibilityIssue(
        text,
        '$family has no face at w${weight.value} '
        '(ships ${weights.toList()..sort()}): bold would be synthesised',
      ));
    }
  }
  return issues;
}

class _Backdrop {
  final Color surface;
  final double opacity;

  const _Backdrop(this.surface, this.opacity);
}

/// The opaque surface behind [element], and the opacity applied to it by
/// ancestors that sit between the two.
_Backdrop _backdropOf(Element element, Color fallback) {
  final List<Color> fills = [];
  double opacity = 1;

  element.visitAncestorElements((Element ancestor) {
    final Color? fill = _fillOf(ancestor);
    if (fill != null && fill.a > 0) {
      fills.add(fill);
      return fill.a < 1; // keep walking under a translucent fill
    }
    // Opacity only dims the text relative to a surface *outside* it.
    final double? fade = _opacityOf(ancestor.widget);
    if (fade != null) opacity *= fade;
    return true;
  });

  Color surface = fallback.a >= 1
      ? fallback
      : Color.alphaBlend(fallback, const Color(0xFFFFFFFF));
  for (final Color fill in fills.reversed) {
    surface = Color.alphaBlend(fill, surface);
  }
  return _Backdrop(surface, opacity);
}

Color? _fillOf(Element element) {
  final Widget widget = element.widget;
  if (widget is ColoredBox) return widget.color;
  if (widget is DecoratedBox &&
      widget.position == DecorationPosition.background) {
    return _decorationColor(widget.decoration);
  }
  if (widget is Ink) return _decorationColor(widget.decoration);
  if (widget is Material) {
    if (widget.type == MaterialType.transparency) return null;
    if (widget.color != null) return widget.color;
    final ThemeData theme = Theme.of(element);
    return widget.type == MaterialType.card
        ? theme.cardColor
        : theme.canvasColor;
  }
  if (widget is Scaffold) {
    return widget.backgroundColor ?? Theme.of(element).scaffoldBackgroundColor;
  }
  return null;
}

Color? _decorationColor(Decoration? decoration) {
  if (decoration is BoxDecoration) {
    return decoration.color ?? decoration.gradient?.colors.first;
  }
  if (decoration is ShapeDecoration) {
    return decoration.color ?? decoration.gradient?.colors.first;
  }
  return null;
}

double? _opacityOf(Widget widget) {
  if (widget is Opacity) return widget.opacity;
  if (widget is AnimatedOpacity) return widget.opacity;
  if (widget is FadeTransition) return widget.opacity.value;
  return null;
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
