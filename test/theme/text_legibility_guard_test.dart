import 'dart:io';

import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/text_legibility_audit.dart' show registeredFontFamilies;

/// Source guard: no POS or kiosk text style may pick a colour that fails WCAG
/// AA on the light surfaces, or a font family pubspec.yaml does not ship.
///
/// It reads every `TextStyle(...)`, `<font style>.copyWith(...)` and
/// `PosUI.text(...)` call, resolves its `color:` through the spec constants
/// (`PosHomeSpec.inkAlpha(0.53)`, `PosHardwareSpec.mutedText`,
/// `Colors.black54`, `Color(0xFFB9B5A6)`, …) and checks it against the
/// darkest page surface. A colour it cannot resolve statically is left to the
/// widget-level audit (`test/helpers/text_legibility_audit.dart`).
///
/// Faint on purpose (a disabled label, which WCAG 1.4.3 exempts)? Put
/// `// legibility: <reason>` on the line above the style call or inside it.
const List<String> _scannedDirs = [
  'lib/features/pos',
  'lib/features/kiosk',
  'lib/features/search',
  'lib/common/widgets',
];

/// Constants resolve from these too (spec files, brand palette, tones).
const List<String> _constantDirs = [..._scannedDirs, 'lib/theme', 'lib/utill'];

/// Text is judged on the darkest light surface it can sit on.
const Color _worstSurface = PosHomeSpec.pageBg;

/// Colours this close to white are drawn on dark fills (labels on black
/// buttons); the light-surface rule does not apply to them.
const double _lightTextMaxRatioOnWhite = 1.6;

const String _marker = 'legibility:';

final RegExp _styleCall = RegExp(
  r'(?<![A-Za-z_])TextStyle\(|'
  r'\b(?:loew|swiss721|inter|rubik|poppins|roboto|robotoMono|jetBrainsMono|scotchDisplay)\w*\.copyWith\(|'
  // `(selected ? loewBold : loewRegular).copyWith(`
  r'\([^()]*\?\s*(?:loew|swiss721|inter|rubik)\w*\s*:\s*(?:loew|swiss721|inter|rubik)\w*\s*\)\.copyWith\(|'
  r'\bPosUI\.text\(|\bPosCloseDaySpec\.text\(|\bposReportText\(',
);

class _Finding {
  final String where;
  final String message;
  const _Finding(this.where, this.message);
  @override
  String toString() => '$where  $message';
}

void main() {
  final _Constants constants = _Constants.scan(_constantDirs);
  final List<File> files = _dartFiles(_scannedDirs);

  test('scans the POS and kiosk sources', () {
    expect(files.length, greaterThan(100));
    expect(constants.color('PosHomeSpec.ink', null), isNotNull);
    // Tones resolve through their opacity constants, as specs alias them.
    expect(constants.color('TextTones.secondary', null), TextTones.secondary);
    expect(constants.color('PosSettingsSpec.inkMuted()', null),
        PosHomeSpec.inkAlpha(TextTones.secondaryOpacity));
  });

  test('every fontFamily literal is registered in pubspec.yaml', () {
    final Set<String> families = registeredFontFamilies.keys.toSet();
    final List<_Finding> findings = [];
    for (final File file in files) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        for (final RegExpMatch m
            in RegExp(r"fontFamily:\s*'([^']+)'").allMatches(lines[i])) {
          if (!families.contains(m.group(1))) {
            findings.add(_Finding('${file.path}:${i + 1}',
                'fontFamily "${m.group(1)}" falls back to another face'));
          }
        }
      }
    }
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  test('no text style is below WCAG AA on the light surfaces', () {
    final List<_Finding> findings = [];
    for (final File file in files) {
      findings.addAll(_auditFile(file, constants));
    }
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  test('no Text is dimmed by a faint Opacity wrapper', () {
    final List<_Finding> findings = [];
    for (final File file in files) {
      findings.addAll(_auditOpacity(file));
    }
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  test('the guard catches the patterns it exists for', () {
    final Directory dir = Directory.systemTemp.createTempSync('legibility');
    addTearDown(() => dir.deleteSync(recursive: true));
    final File probe = File('${dir.path}/probe.dart')..writeAsStringSync('''
const Color _kHint = Color(0xFFB9B5A6);
Widget a() => Text('x', style: swiss721Light.copyWith(
      fontSize: 11, color: PosHomeSpec.inkAlpha(0.53)));
Widget b() => Text('x', style: TextStyle(color: _kHint));
Widget c() => Text('x', style: TextStyle(color: Colors.black45));
Widget d() => Text('x', style: TextStyle(color: TextTones.secondary));
Widget e() => Text('x', style: TextStyle(
      // legibility: disabled label
      color: TextTones.disabled));
Widget f() => Text('x', style: loewBold.copyWith(
      fontSize: 28, color: PosHomeSpec.inkAlpha(0.5)));
Widget g() => Text('x', style: TextStyle(
      color: on ? Colors.white : PosHomeSpec.inkAlpha(0.4)));
Widget h() => Text('x', style: loewRegular.copyWith(
      color: PosSettingsSpec.inkMuted(0.4)));
Widget i() => Opacity(
      opacity: 0.6,
      child: Text('x', style: TextStyle(color: TextTones.primary)));
''');
    final _Constants withProbe = _Constants.scan(_constantDirs)..addFile(probe);
    final List<int> lines = [
      for (final _Finding f in _auditFile(probe, withProbe))
        int.parse(f.where.split(':').last),
    ];
    // a (faint ink), b (opaque grey), c (black45), g (faint branch),
    // h (a tone function's default). d passes, e is marked, f is large text.
    expect(lines, [3, 4, 5, 13, 15]);
    expect(_auditOpacity(probe).map((f) => f.where.split(':').last), ['16']);
  });
}

List<File> _dartFiles(List<String> dirs) => [
      for (final String d in dirs)
        if (Directory(d).existsSync())
          ...Directory(d)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')),
    ]..sort((a, b) => a.path.compareTo(b.path));

List<_Finding> _auditFile(File file, _Constants constants) {
  final String src = file.readAsStringSync();
  final List<_Finding> findings = [];
  for (final RegExpMatch call in _styleCall.allMatches(src)) {
    final int open = call.end - 1;
    final int close = _matchingParen(src, open);
    if (close < 0) continue;
    final String args = src.substring(open + 1, close);
    final int lineStart = src.lastIndexOf('\n', call.start) + 1;
    if (src.substring(lineStart, call.start).contains('//')) continue;
    final int prevLineStart =
        lineStart > 0 ? src.lastIndexOf('\n', lineStart - 2) + 1 : 0;
    if (args.contains(_marker) ||
        src.substring(prevLineStart, call.start).contains(_marker)) {
      continue;
    }

    final Map<String, String> named = _namedArgs(args
        .replaceAll(RegExp(r"'(?:[^'\\\n]|\\.)*'"), "''")
        .replaceAll(RegExp(r'//[^\n]*'), ''));
    final String? colorExpr = named['color'];
    if (colorExpr == null) continue;

    final double floor = TextLegibility.requiredContrast(
      constants.number(named['fontSize'] ?? named['size'], file.path) ?? 14,
      _weightOf(named['fontWeight'] ?? named['weight'], call.group(0)!),
    );
    for (final String branch in _branches(colorExpr)) {
      final Color? color = constants.color(branch, file.path);
      if (color == null) continue;
      if (TextLegibility.contrastRatio(
              color.withValues(alpha: 1), const Color(0xFFFFFFFF)) <
          _lightTextMaxRatioOnWhite) {
        continue;
      }
      final double ratio = TextLegibility.contrastRatio(color, _worstSurface);
      if (ratio < floor) {
        final int colorAt = src.indexOf('color:', open);
        final int line = '\n'.allMatches(src.substring(0, colorAt)).length + 1;
        findings.add(_Finding(
          '${file.path}:$line',
          '${branch.trim()} is ${ratio.toStringAsFixed(2)}:1 '
              '(needs ${floor.toStringAsFixed(1)}:1); use TextTones',
        ));
      }
    }
  }
  return findings;
}

/// `Opacity(opacity: x, child: Text(...))` with x under the secondary tone:
/// the run is fainter than any [TextTones] colour would draw it.
List<_Finding> _auditOpacity(File file) {
  final String src = file.readAsStringSync();
  final List<_Finding> findings = [];
  final RegExp wrapped = RegExp(
      r'Opacity\(\s*opacity:\s*([0-9.]+)\s*,\s*child:\s*(?:const\s+)?Text\(');
  for (final RegExpMatch m in wrapped.allMatches(src)) {
    final double opacity = double.parse(m.group(1)!);
    if (opacity >= TextTones.secondaryOpacity) continue;
    final int lineStart = src.lastIndexOf('\n', m.start) + 1;
    final int prevLineStart =
        lineStart > 0 ? src.lastIndexOf('\n', lineStart - 2) + 1 : 0;
    if (src.substring(prevLineStart, m.end).contains(_marker)) continue;
    final int line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
    findings.add(_Finding('${file.path}:$line',
        'Opacity($opacity) dims a Text; colour it with TextTones instead'));
  }
  return findings;
}

int _matchingParen(String s, int open) {
  int depth = 0;
  for (int i = open; i < s.length; i++) {
    final String c = s[i];
    if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      final int nl = s.indexOf('\n', i);
      if (nl < 0) return -1;
      i = nl;
      continue;
    }
    if (c == "'" || c == '"') {
      int j = i + 1;
      while (j < s.length && s[j] != c && s[j] != '\n') {
        if (s[j] == '\\') j++;
        j++;
      }
      i = j;
      continue;
    }
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Top-level `name: value` arguments of a call's argument list.
Map<String, String> _namedArgs(String args) {
  final Map<String, String> out = {};
  int depth = 0;
  int start = 0;
  void take(String part) {
    final RegExpMatch? m =
        RegExp(r'^\s*(?://[^\n]*\n\s*)*(\w+)\s*:\s*([\s\S]+?)\s*$')
            .firstMatch(part);
    if (m != null) out[m.group(1)!] = m.group(2)!;
  }

  for (int i = 0; i < args.length; i++) {
    final String c = args[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ',' && depth == 0) {
      take(args.substring(start, i));
      start = i + 1;
    }
  }
  take(args.substring(start));
  return out;
}

/// `cond ? a : b` yields both colours; anything else yields itself.
List<String> _branches(String expr) {
  final String e = expr.replaceAll(RegExp(r'//[^\n]*'), '').trim();
  int depth = 0;
  for (int i = 0; i < e.length; i++) {
    final String c = e[i];
    if (c == '(' || c == '[') depth++;
    if (c == ')' || c == ']') depth--;
    if (c == '?' &&
        depth == 0 &&
        i + 1 < e.length &&
        e[i + 1] != '.' &&
        e[i + 1] != '?') {
      final String rest = e.substring(i + 1);
      int d = 0;
      for (int j = 0; j < rest.length; j++) {
        if (rest[j] == '(' || rest[j] == '[') d++;
        if (rest[j] == ')' || rest[j] == ']') d--;
        if (rest[j] == ':' && d == 0) {
          return [
            ..._branches(rest.substring(0, j)),
            ..._branches(rest.substring(j + 1))
          ];
        }
      }
    }
  }
  return [e];
}

FontWeight _weightOf(String? expr, String call) {
  final RegExpMatch? m = RegExp(r'FontWeight\.w(\d)00').firstMatch(expr ?? '');
  if (m != null) return FontWeight.values[int.parse(m.group(1)!) - 1];
  if (expr != null && expr.contains('FontWeight.bold')) return FontWeight.w700;
  if (RegExp(r'ExtraBold|800').hasMatch(call)) return FontWeight.w800;
  if (RegExp(r'Bold|700').hasMatch(call)) return FontWeight.w700;
  return FontWeight.w400;
}

/// Colour and number constants declared across the scanned sources, keyed
/// `Class.name` (or `file|name` for top-level privates).
class _Constants {
  final Map<String, String> _colors = {};
  final Map<String, String> _numbers = {};
  final Map<String, List<String>> _byName = {};

  /// `static Color inkMuted([double a = 0.6]) => ink.withValues(alpha: a);`
  /// keyed `Class.fn`: (base colour ref, default alpha).
  final Map<String, (String, String?)> _toneFns = {};

  static const Map<String, int> _materialBlack = {
    'black87': 0xDE000000,
    'black54': 0x8A000000,
    'black45': 0x73000000,
    'black38': 0x61000000,
    'black26': 0x42000000,
    'black12': 0x1F000000,
  };

  static _Constants scan(List<String> dirs) {
    final _Constants c = _Constants();
    _dartFiles(dirs).forEach(c.addFile);
    return c;
  }

  void addFile(File f) {
    // Typed (`const Color x = …`) and inferred (`const _kInk = Color(…)`).
    final RegExp decl = RegExp(
        r'(?:static\s+)?(?:const|final)\s+(?:(Color|double)\s+)?(\w+)\s*=\s*([^;]+);');
    final RegExp classDecl =
        RegExp(r'^(?:abstract\s+)?(?:final\s+)?class\s+(\w+)', multiLine: true);
    final RegExp toneFn = RegExp(
        r'static\s+Color\s+(\w+)\(\s*\[?\s*double\s+(\w+)(?:\s*=\s*([\w.]+))?\s*\]?\s*\)\s*=>\s*([\w.]+)\.withValues\(\s*alpha:\s*\2\s*\)');
    final String src = f.readAsStringSync();
    final List<RegExpMatch> classes = classDecl.allMatches(src).toList();
    String? ownerAt(int offset) {
      String? owner;
      for (final RegExpMatch k in classes) {
        if (k.start > offset) break;
        owner = k.group(1);
      }
      return owner;
    }

    for (final RegExpMatch m in toneFn.allMatches(src)) {
      final String? owner = ownerAt(m.start);
      if (owner == null) continue;
      final String base =
          m.group(4)!.contains('.') ? m.group(4)! : '$owner.${m.group(4)}';
      _toneFns['$owner.${m.group(1)}'] = (base, m.group(3));
    }
    for (final RegExpMatch m in decl.allMatches(src)) {
      final String value = m.group(3)!.trim();
      // An untyped alias (`const _kInk = PosHomeSpec.ink;`) could be either;
      // it is stored as both and only resolves as what it really is.
      final bool alias = RegExp(r'^[A-Za-z_]\w*(\.\w+)?$').hasMatch(value);
      final String? type = m.group(1) ??
          (RegExp(r'^(?:const\s+)?Colors?\b').hasMatch(value)
              ? 'Color'
              : double.tryParse(value) != null
                  ? 'double'
                  : alias
                      ? 'alias'
                      : null);
      if (type == null) continue;
      final String? owner = ownerAt(m.start);
      final bool topLevel = !src
          .substring(src.lastIndexOf('\n', m.start) + 1, m.start)
          .startsWith(' ');
      final String key = topLevel || owner == null
          ? '${f.path}|${m.group(2)}'
          : '$owner.${m.group(2)}';
      if (type == 'Color' || type == 'alias') _colors[key] = value;
      if (type == 'double' || type == 'alias') _numbers[key] = value;
      _byName.putIfAbsent(m.group(2)!, () => []).add(key);
    }
  }

  String? _keyFor(String ref, String? file, Map<String, Object> table) {
    final List<String> parts = ref.split('.');
    if (parts.length == 2 && table.containsKey(ref)) return ref;
    final String name = parts.last;
    if (file != null && table.containsKey('$file|$name')) return '$file|$name';
    final List<String> keys =
        (_byName[name] ?? const []).where(table.containsKey).toList();
    if (parts.length == 2) {
      final String owned = '${parts.first}.$name';
      if (table.containsKey(owned)) return owned;
      return null;
    }
    return keys.length == 1 ? keys.single : null;
  }

  double? number(String? expr, String file, [int depth = 0]) {
    if (expr == null || depth > 8) return null;
    final String e = expr.trim();
    final double? literal = double.tryParse(e);
    if (literal != null) return literal;
    if (!RegExp(r'^[A-Za-z_]\w*(\.\w+)?$').hasMatch(e)) return null;
    final String? key = _keyFor(e, file, _numbers);
    return key == null ? null : number(_numbers[key], file, depth + 1);
  }

  Color? color(String expr, String? file, [int depth = 0]) {
    if (depth > 8) return null;
    String e = expr.trim();
    if (e.startsWith('const ')) e = e.substring(6).trim();

    RegExpMatch? m = RegExp(r'^Color\(0x([0-9A-Fa-f]{8})\)$').firstMatch(e);
    if (m != null) return Color(int.parse(m.group(1)!, radix: 16));

    m = RegExp(
            r'^Color\.fromRGBO\(\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*([\w.]+)\s*,?\s*\)$')
        .firstMatch(e);
    if (m != null) {
      final List<int> rgb = [
        for (int i = 1; i <= 3; i++) int.parse(m.group(i)!),
      ];
      final double? opacity = number(m.group(4), file ?? '');
      return opacity == null
          ? null
          : Color.fromRGBO(rgb[0], rgb[1], rgb[2], opacity);
    }

    m = RegExp(r'^Colors\.(black\d\d)$').firstMatch(e);
    if (m != null && _materialBlack.containsKey(m.group(1))) {
      return Color(_materialBlack[m.group(1)]!);
    }
    if (e == 'Colors.black') return const Color(0xFF000000);
    if (e == 'Colors.white') return const Color(0xFFFFFFFF);
    if (RegExp(r'^Colors\.grey(\b|\.|\[)').hasMatch(e)) {
      final RegExpMatch? shade = RegExp(r'(\d{3})').firstMatch(e);
      const Map<String, int> greys = {
        '300': 0xFFE0E0E0,
        '400': 0xFFBDBDBD,
        '500': 0xFF9E9E9E,
        '600': 0xFF757575,
        '700': 0xFF616161,
        '800': 0xFF424242,
      };
      return Color(greys[shade?.group(1) ?? '500'] ?? 0xFF9E9E9E);
    }

    // Alphas may be literals or named constants (`PosOrdersSpec.searchHintAlpha`).
    m = RegExp(r'^(?:(\w+)\.)?inkAlpha\(\s*([\w.]+)\s*,?\s*\)$').firstMatch(e);
    if (m != null) {
      final double? alpha = number(m.group(2), file ?? '');
      final Color? ink =
          color('${m.group(1) ?? 'PosHomeSpec'}.ink', file, depth + 1) ??
              color('PosHomeSpec.ink', file, depth + 1);
      return alpha == null ? null : ink?.withValues(alpha: alpha);
    }

    m = RegExp(
            r'^(.+?)\.(?:withValues\(\s*alpha:|withOpacity\()\s*([\w.]+)\s*,?\s*\)$')
        .firstMatch(e);
    if (m != null) {
      final double? alpha = number(m.group(2), file ?? '');
      if (alpha == null) return null;
      return color(m.group(1)!, file, depth + 1)?.withValues(alpha: alpha);
    }

    m = RegExp(r'^(\w+)\.(\w+)\(\s*([\w.]*)\s*,?\s*\)$').firstMatch(e);
    if (m != null && _toneFns.containsKey('${m.group(1)}.${m.group(2)}')) {
      final (String base, String? fallback) =
          _toneFns['${m.group(1)}.${m.group(2)}']!;
      final double? alpha =
          number(m.group(3)!.isEmpty ? fallback : m.group(3), file ?? '');
      if (alpha == null) return null;
      return color(base, file, depth + 1)?.withValues(alpha: alpha);
    }

    if (RegExp(r'^[A-Za-z_]\w*(\.\w+)?$').hasMatch(e)) {
      final String? key = _keyFor(e, file, _colors);
      if (key != null) return color(_colors[key]!, file, depth + 1);
    }
    return null;
  }
}
