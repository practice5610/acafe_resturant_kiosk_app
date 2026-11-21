import 'package:flutter/widgets.dart';

/// Which kiosk composition a screen is rendered in.
enum KioskLayoutMode { portrait, landscape }

/// The plain width >= height rule, read fresh from the CURRENT window on
/// every build — no memory, no per-order lock.
///
/// An earlier version of this file latched the decision for the whole order
/// so a physical tablet rotation mid-order could never re-flow the screen.
/// In practice (Phase 3B) that latch made a resized browser window get stuck
/// showing the wrong layout until the customer navigated back to a start
/// screen, which is the wrong trade-off for this project's actual deployment
/// (resizable windows, not just a tablet that rotates once). The rule is now
/// simply: landscape when the window is at least as wide as it is tall,
/// recomputed every time the router switch resolves. A square window counts
/// as landscape (`>=`, not `>`).
KioskLayoutMode classifyKioskLayout(Size window) =>
    window.width >= window.height
        ? KioskLayoutMode.landscape
        : KioskLayoutMode.portrait;
