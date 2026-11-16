import 'package:flutter/material.dart';

import '../../domain/entities/order.dart';

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) => Text('#${order.id}');
}
