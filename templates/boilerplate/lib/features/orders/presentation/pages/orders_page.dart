import 'dart:async';

import 'package:kit_app/core/common/widgets/app_top_bar.dart';
import 'package:kit_app/core/common/widgets/empty_state.dart';
import 'package:kit_app/core/common/widgets/error_state.dart';
import 'package:kit_app/core/common/widgets/loading_state.dart';
import 'package:kit_app/core/common/widgets/notifier_provider.dart';
import 'package:kit_app/core/common/widgets/show_app_toast.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/features/orders/presentation/controllers/orders_controller.dart';
import 'package:kit_app/features/orders/presentation/widgets/orders_list.dart';
import 'package:material_ui/material_ui.dart';

/// The orders tab: the four states of a data screen (F12), loading, error, empty and the list.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  static const path = '/orders';
  static const name = 'orders';

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  @override
  void initState() {
    super.initState();
    // The first load starts after the first frame, never from build(): build runs again on every rebuild (F3).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(NotifierProvider.read<OrdersController>(context).load());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = NotifierProvider.of<OrdersController>(context);
    final l10n = context.l10n;
    final failure = controller.failure;
    final Widget body;
    if (controller.orders.isNotEmpty) {
      body = OrdersList(controller: controller, onRefresh: _refresh);
    } else if (failure != null) {
      body = ErrorState(
        message: controller.messageFor(failure, l10n),
        onRetry: () => unawaited(controller.load()),
      );
    } else if (controller.hasLoaded && !controller.isLoading) {
      body = EmptyState(
        title: l10n.ordersEmptyTitle,
        message: l10n.ordersEmptyBody,
      );
    } else {
      body = const LoadingState();
    }
    // No SafeArea: the top bar pads itself under the status bar, the list pads its end above the bottom bar (F9).
    return Scaffold(
      body: Column(
        children: [
          AppTopBar(title: l10n.ordersTitle),
          Expanded(child: body),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    final controller = NotifierProvider.read<OrdersController>(context);
    final failure = await controller.load();
    // The page may have closed while the call ran: never use a context that is gone (F15).
    if (failure == null || !mounted) {
      return;
    }
    showAppToast(controller.messageFor(failure, context.l10n));
  }
}
