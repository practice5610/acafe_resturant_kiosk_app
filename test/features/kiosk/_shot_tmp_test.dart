import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'kiosk_welcome_screen_test.dart' as t;
import '../../helpers/kiosk_layout_harness.dart';

void main() {
  for (final s in [const Size(1080, 1920), const Size(390, 844)]) {
    testWidgets('shot ${s.width}', (tester) async {
      await loadKioskTestFonts();
      await t.pumpWelcome(tester, size: s, realTranslations: true);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump(const Duration(milliseconds: 600));
      final boundary = tester.firstRenderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
      await tester.runAsync(() async {
        final img = await boundary.toImage();
        final bd = await img.toByteData(format: ui.ImageByteFormat.png);
        File('/private/tmp/claude-501/-Users-apple-Documents-GitHub-Acafe/4f7f82f3-a685-4794-9c60-537b5bcfb298/scratchpad/shot_${s.width.toInt()}.png').writeAsBytesSync(bd!.buffer.asUint8List());
      });
    });
  }
}
