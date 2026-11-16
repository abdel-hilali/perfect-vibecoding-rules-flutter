import 'package:flutter/material.dart';
import 'package:shop/features/orders/domain/usecases/get_orders.dart';

import '../../domain/entities/member.dart';

class MembersPage extends StatelessWidget {
  const MembersPage({super.key, this.members = const [], this.getOrders});

  static const path = '/members';

  final List<Member> members;
  final GetOrders? getOrders;

  @override
  Widget build(BuildContext context) => ListView(children: [for (final m in members) Text(m.name)]);
}
