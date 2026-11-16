import 'dart:async';

import 'package:flutter/services.dart';
import 'package:kit_app/core/common/widgets/show_app_toast.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Back on a tab root (F7): the first press shows a toast, a second press within [window] leaves the app.
///
/// MainShell wraps the tabs in it. go_router first asks the open tab's own navigator, so a pushed page pops as
/// usual and this runs only when the tab is at its root: the PopScope blocks the pop that would close the app.
class RootBackHandler extends StatefulWidget {
  const RootBackHandler({
    super.key,
    required this.child,
    this.onExit = SystemNavigator.pop,
    this.clock = DateTime.now,
  });

  final Widget child;

  /// Leaves the app. A test passes a fake to see it called.
  final Future<void> Function() onExit;

  /// A test passes a fixed clock to step over [window].
  final DateTime Function() clock;

  static const window = Duration(seconds: 2);

  @override
  State<RootBackHandler> createState() => _RootBackHandlerState();
}

class _RootBackHandlerState extends State<RootBackHandler> {
  DateTime? _firstPressAt;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onBack();
        }
      },
      child: widget.child,
    );
  }

  void _onBack() {
    final now = widget.clock();
    final first = _firstPressAt;
    if (first != null && now.difference(first) <= RootBackHandler.window) {
      unawaited(widget.onExit());
      return;
    }
    _firstPressAt = now;
    showAppToast(context.l10n.commonPressBackAgain);
  }
}
