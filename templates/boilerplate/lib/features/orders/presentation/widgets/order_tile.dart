import 'package:kit_app/core/common/data/formatters.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_radius.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:kit_app/features/orders/domain/entities/order.dart';
import 'package:kit_app/features/orders/presentation/widgets/order_status_chip.dart';
import 'package:material_ui/material_ui.dart';

/// One order in the list: the number and status, the date, the item count, and the total at the end.
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: AppRadius.card,
        border: Border.all(color: colors.outline, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A Wrap, not a Row: at a large text scale the chip moves under the number instead of
                  // overflowing.
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.ordersNumber(order.number),
                        style: text.titleSmall,
                      ),
                      OrderStatusChip(status: order.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.ordersPlacedOn(order.createdAt.toLocal()),
                    style: text.bodyMuted,
                  ),
                  Text(
                    l10n.ordersItemCount(order.itemCount),
                    style: text.bodyMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              formatMoney(order.totalMinor, order.currency, l10n.localeName),
              style: text.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
