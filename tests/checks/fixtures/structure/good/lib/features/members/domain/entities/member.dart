import '../../../orders/domain/entities/order.dart';

// A feature may read another feature's entity through its domain/ (F2).
class Member {
  const Member({required this.name, this.lastOrder});

  final String name;
  final Order? lastOrder;
}
