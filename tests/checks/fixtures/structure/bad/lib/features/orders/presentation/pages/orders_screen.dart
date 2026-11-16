import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shop/features/orders/data/models/order.dart';

import '../../../members/presentation/widgets/member_card.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Container(color: Colors.red),
        const ColoredBox(color: Color(0xFF00FF00)),
        ColoredBox(color: Color.fromARGB(255, 0, 0, 0)),
        ColoredBox(color: Color.fromRGBO(0, 0, 0, 1)),
        const Icon(Icons.add),
        SvgPicture.asset('assets/icons/common/cart.svg'),
        const Text('Hello orders'),
        const TextField(decoration: InputDecoration(hintText: 'Search orders')),
        IconButton(tooltip: 'More', onPressed: () {}, icon: const SizedBox()),
        const MemberCard(),
      ],
    );
  }

  Widget _buildHeader() => const SizedBox(height: 8);
}
