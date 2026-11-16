import 'dart:async';

import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:kit_app/features/orders/presentation/controllers/orders_controller.dart';
import 'package:kit_app/features/orders/presentation/widgets/order_tile.dart';
import 'package:material_ui/material_ui.dart';

/// The data state of the orders screen: the rows, pull to refresh, and the next page when the end comes near.
class OrdersList extends StatelessWidget {
  const OrdersList({
    super.key,
    required this.controller,
    required this.onRefresh,
  });

  final OrdersController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final orders = controller.orders;
    final showFooter = controller.hasMore || controller.moreFailure != null;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.colors.primary,
      child: ListView.builder(
        // Always scrollable, so pull to refresh works even when the rows fit the screen.
        physics: const AlwaysScrollableScrollPhysics(),
        // The end pads by the bottom inset: under a bottom bar that inset is 0, on a pushed page it is the
        // gesture bar, so the last row is never hidden behind it (F9).
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: orders.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == orders.length) {
            // A new key for every new list, so the footer of the next page asks again when it comes into view.
            return _LoadMoreFooter(
              key: ObjectKey(orders),
              failed: controller.moreFailure != null,
              onLoadMore: () => unawaited(controller.loadMore()),
            );
          }
          final order = orders[index];
          // Keys from stable ids, never the index (F12): rows keep their state when the list changes.
          return Padding(
            key: ValueKey<String>(order.id),
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: OrderTile(order: order),
          );
        },
      ),
    );
  }
}

/// The end of the list: it asks for the next page when it is built (it comes near the screen), or offers a retry
/// after a failure. Built, not scrolled to: a first page that fits the screen still loads the next one.
class _LoadMoreFooter extends StatefulWidget {
  const _LoadMoreFooter({
    super.key,
    required this.failed,
    required this.onLoadMore,
  });

  final bool failed;
  final VoidCallback onLoadMore;

  @override
  State<_LoadMoreFooter> createState() => _LoadMoreFooterState();
}

class _LoadMoreFooterState extends State<_LoadMoreFooter> {
  @override
  void initState() {
    super.initState();
    if (!widget.failed) {
      // Never during build: loadMore notifies, and a notify while building throws.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onLoadMore();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.failed) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Text(
              l10n.ordersLoadMoreFailed,
              style: context.text.bodyMuted,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: widget.onLoadMore,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: SizedBox.square(
          dimension: AppSpacing.xl,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colors.primary,
          ),
        ),
      ),
    );
  }
}
