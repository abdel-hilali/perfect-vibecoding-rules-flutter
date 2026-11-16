import 'package:flutter/material.dart';

import '../../../../core/common/widgets/app_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../controllers/orders_controller.dart';
import '../widgets/order_tile.dart';

// Colors.red, Icon(Icons.add) and Text('Hello') in a comment are not code.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key, required this.controller});

  static const path = '/orders';

  final OrdersController controller;

  // One counted line more than the good fixture: 21, over the limit of 20.
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const note = 'Colors.red and Icon(Icons.add) in a string';
    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: [
          const AppIcon(AppIcons.orders),
          Text('${controller.orders.length}'),
          Text(note.substring(0, 0)),
          const Text('42 / 7'),
          for (final order in controller.orders)
            OrderTile(key: ValueKey(order.id), order: order),
          Container(color: Colors.transparent, height: 1),
          IconButton(tooltip: controller.refreshLabel, onPressed: controller.load,
              icon: const AppIcon(AppIcons.refresh)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
