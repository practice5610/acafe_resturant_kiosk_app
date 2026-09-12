import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pin_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Manager step-up: an Employee taps the lock icon, a Manager/Owner punches
/// their own PIN here, and the manager tabs unlock for the rest of this
/// session without ending the Employee's own shift.
///
/// Hosts [PosPinCard] unmodified inside a [Dialog] — the card already knows
/// nothing about providers or routing, so the only new code here is wiring
/// its `onSubmit` to [PosSessionProvider.elevate] and popping on success.
class PosPinModal extends StatelessWidget {
  const PosPinModal({super.key});

  /// Shows the modal and returns true once a manager PIN elevates access.
  static Future<bool> show(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const PosPinModal(),
    );
    return result ?? false;
  }

  Future<bool> _submit(BuildContext context, String pin) async {
    final session = context.read<PosSessionProvider>();
    final bool ok = await session.elevate(pin);
    if (!ok) return false;
    if (context.mounted) Navigator.of(context).pop(true);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PosPinSpec.board),
        child: PosPinCard(
          pinLength: 4,
          onSubmit: (pin) => _submit(context, pin),
        ),
      ),
    );
  }
}
