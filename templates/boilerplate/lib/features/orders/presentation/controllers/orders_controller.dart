import 'package:flutter/foundation.dart';
import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/l10n/failure_messages.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/usecases/result.dart';
import 'package:kit_app/features/orders/domain/entities/order.dart';
import 'package:kit_app/features/orders/domain/entities/orders_failures.dart';
import 'package:kit_app/features/orders/domain/usecases/get_orders.dart';

/// The state of the orders screen (F3): the rows, the paging, and what went wrong.
///
/// Two guards every controller has: `_disposed`, because an answer can arrive after the screen closed, and
/// notifying a disposed ChangeNotifier throws; and `_generation`, because a slow old answer must never overwrite
/// a newer one (a refresh started while the first load still ran).
class OrdersController extends ChangeNotifier {
  OrdersController(this._getOrders);

  final GetOrders _getOrders;

  List<Order> _orders = const [];
  String? _nextCursor;
  bool _hasLoaded = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  Failure? _failure;
  Failure? _moreFailure;
  bool _disposed = false;
  int _generation = 0;

  List<Order> get orders => _orders;

  /// True once a first page arrived, even an empty one: before that the screen shows the loading state.
  bool get hasLoaded => _hasLoaded;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _nextCursor != null;

  /// Why the last full load failed. The rows on screen stay; the error state shows only when there are none.
  Failure? get failure => _failure;

  /// Why the last "load more" failed; the list footer offers a retry.
  Failure? get moreFailure => _moreFailure;

  /// The first page; also the refresh. Returns the failure, if any, so a pull to refresh can say why it failed.
  Future<Failure?> load() async {
    final generation = ++_generation;
    _isLoading = true;
    // A "load more" still running belongs to the old list: its answer will be dropped.
    _isLoadingMore = false;
    _failure = null;
    _notify();
    final result = await _getOrders();
    if (_isStale(generation)) {
      return null;
    }
    _isLoading = false;
    switch (result) {
      case Success(:final value):
        _orders = value.items;
        _nextCursor = value.nextCursor;
        _hasLoaded = true;
        _moreFailure = null;
      case FailureResult(:final failure):
        _failure = failure;
    }
    _notify();
    return _failure;
  }

  /// The next page, appended. Does nothing while another load runs or when the server said there is no more.
  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _isLoading || _isLoadingMore) {
      return;
    }
    // Not a new generation: a load() started meanwhile makes this page stale, and it is dropped.
    final generation = _generation;
    _isLoadingMore = true;
    _moreFailure = null;
    _notify();
    final result = await _getOrders(cursor: cursor);
    if (_isStale(generation)) {
      return;
    }
    _isLoadingMore = false;
    switch (result) {
      case Success(:final value):
        _orders = [..._orders, ...value.items];
        _nextCursor = value.nextCursor;
      case FailureResult(:final failure):
        _moreFailure = failure;
    }
    _notify();
  }

  /// The user's text for [failure] (F11): this feature's own failures first, then the core kinds.
  String messageFor(Failure failure, AppLocalizations l10n) {
    return failure is OrdersDisabledFailure
        ? l10n.ordersErrorDisabled
        : l10n.failureMessage(failure);
  }

  bool _isStale(int generation) => _disposed || generation != _generation;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
