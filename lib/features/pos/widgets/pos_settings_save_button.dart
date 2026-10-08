import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_nav_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// "Save Changes" button for batch-form Settings sections (Figma 1641:3920).
///
/// Lifted verbatim out of `pos_general_settings_panel.dart`, where it was
/// file-private, so General and Hardware share one button instead of drifting.
/// Behaviour is unchanged: press-scale, dimmed while clean, spinner while
/// saving. Add-ons and Payments can adopt it when they land.
///
/// [PosSettingsSaveButton.compact] is the primary-CTA variant (customize
/// screen's Add to Cart): fills the width its parent gives it at
/// [PosUI.buttonHeight], Dine In toggle radius, nav-pill label weight, hover
/// dim and a spinner that never changes the button's size.
class PosSettingsSaveButton extends StatefulWidget {
  final bool loading;

  /// Settings: false = form is clean. Compact: false = not ready yet (a
  /// required option is missing). Either way the button is dimmed but still
  /// tappable, so the handler can explain what is missing.
  final bool dirty;

  /// Always set for Settings. Compact: null renders the truly disabled state
  /// (no tap, no pointer) — e.g. Confirm Payment with nothing to pay.
  final VoidCallback? onPressed;
  final String label;
  final bool compact;

  const PosSettingsSaveButton({
    super.key,
    required this.loading,
    required this.dirty,
    required this.onPressed,
  })  : label = 'Save Changes',
        compact = false;

  const PosSettingsSaveButton.compact({
    super.key,
    required this.label,
    this.onPressed,
    bool enabled = true,
    this.loading = false,
  })  : dirty = enabled,
        compact = true;

  @override
  State<PosSettingsSaveButton> createState() => _PosSettingsSaveButtonState();
}

class _PosSettingsSaveButtonState extends State<PosSettingsSaveButton> {
  static const Duration _compactMotion = Duration(milliseconds: 140);

  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompact() : _buildSettings();
  }

  Widget _buildSettings() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.loading ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: widget.dirty || widget.loading ? 1 : 0.72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PosSettingsSpec.ink,
                borderRadius: BorderRadius.circular(PosSettingsSpec.saveRadius),
                boxShadow: PosSettingsSpec.saveShadow,
              ),
              child: Padding(
                padding: PosSettingsSpec.savePadding,
                child: widget.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PosSettingsSpec.pageBg,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: loewBold.copyWith(
                          fontSize: PosSettingsSpec.saveLabelSize,
                          color: PosSettingsSpec.pageBg,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact() {
    final bool loading = widget.loading;
    final VoidCallback? onPressed = loading ? null : widget.onPressed;
    // Loading keeps the solid fill under its spinner; only "not ready" and
    // "no action at all" read as muted.
    final bool muted = !loading && (!widget.dirty || widget.onPressed == null);
    final double opacity = muted
        ? 0.38
        : _pressed
            ? 0.82
            : _hovered
                ? 0.9
                : 1;

    return AnimatedScale(
      scale: _pressed && !muted ? 0.98 : 1,
      duration: _compactMotion,
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: _compactMotion,
        opacity: opacity,
        child: Material(
          color: PosUI.ink,
          borderRadius: BorderRadius.circular(PosHomeSpec.orderTypeRadius),
          child: InkWell(
            onTap: onPressed,
            onHover: (h) => setState(() => _hovered = h),
            onHighlightChanged: (p) => setState(() => _pressed = p),
            mouseCursor: onPressed == null
                ? SystemMouseCursors.basic
                : muted
                    ? SystemMouseCursors.forbidden
                    : SystemMouseCursors.click,
            // The opacity/scale change is the feedback; no ripple.
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            borderRadius: BorderRadius.circular(PosHomeSpec.orderTypeRadius),
            child: Container(
              height: PosUI.buttonHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: PosUI.gutter),
              // The label stays laid out under the spinner so the button
              // keeps its exact size while loading.
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: loading ? 0 : 1,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: loewMedium.copyWith(
                        fontSize: PosUI.bodySize,
                        height: PosNavPill.labelHeight,
                        color: PosUI.pageBg,
                      ),
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PosUI.pageBg,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
