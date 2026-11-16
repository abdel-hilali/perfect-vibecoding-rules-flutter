import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_radius.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:kit_app/features/orders/domain/entities/order_status.dart';
import 'package:material_ui/material_ui.dart';

/// The status of an order as a small outlined pill. Each colour is a token that keeps 4.5:1 on the card (tested),
/// and the label says the status in words: colour is never the only signal.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final (label, color) = switch (status) {
      OrderStatus.pending => (l10n.ordersStatusPending, colors.warning),
      OrderStatus.paid => (l10n.ordersStatusPaid, colors.primary),
      OrderStatus.shipped => (l10n.ordersStatusShipped, colors.success),
      OrderStatus.cancelled => (l10n.ordersStatusCancelled, colors.danger),
      OrderStatus.unknown => (l10n.ordersStatusUnknown, colors.onSurfaceMuted),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.chip,
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(label, style: context.text.caption.copyWith(color: color)),
      ),
    );
  }
}
