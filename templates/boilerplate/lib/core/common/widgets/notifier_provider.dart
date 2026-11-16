import 'package:flutter/widgets.dart';

/// Serves a ChangeNotifier controller to a subtree (F3).
///
/// The route creates the controller from the feature's module; the page reads it. `of` listens: the caller rebuilds
/// on every notify. `read` does not: use it in callbacks and in initState. The controller is disposed with the
/// provider, unless [autoDispose] is false (an app-wide controller that outlives the page).
class NotifierProvider<T extends ChangeNotifier> extends StatefulWidget {
  const NotifierProvider({
    super.key,
    required this.create,
    required this.child,
    this.autoDispose = true,
  });

  final T Function() create;
  final Widget child;
  final bool autoDispose;

  static T of<T extends ChangeNotifier>(BuildContext context) {
    return _notifierOf<T>(
      context.dependOnInheritedWidgetOfExactType<_NotifierScope<T>>(),
    );
  }

  static T read<T extends ChangeNotifier>(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<_NotifierScope<T>>()
        ?.widget;
    return _notifierOf<T>(widget is _NotifierScope<T> ? widget : null);
  }

  static T _notifierOf<T extends ChangeNotifier>(_NotifierScope<T>? scope) {
    final notifier = scope?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'No NotifierProvider<$T> above this widget: the route must wrap the page in one.',
      );
    }
    return notifier;
  }

  @override
  State<NotifierProvider<T>> createState() => _NotifierProviderState<T>();
}

class _NotifierProviderState<T extends ChangeNotifier>
    extends State<NotifierProvider<T>> {
  late final T _notifier = widget.create();

  @override
  void dispose() {
    if (widget.autoDispose) {
      _notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _NotifierScope<T>(notifier: _notifier, child: widget.child);
}

class _NotifierScope<T extends ChangeNotifier> extends InheritedNotifier<T> {
  const _NotifierScope({required T super.notifier, required super.child});
}
