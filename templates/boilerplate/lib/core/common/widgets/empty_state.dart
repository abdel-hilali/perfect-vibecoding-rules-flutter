import 'package:kit_app/core/common/widgets/state_message.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_icons.dart';
import 'package:material_ui/material_ui.dart';

/// The empty state of a data screen (F12): what is missing and what to do about it, never a blank page.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = AppIcons.empty,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;

  /// The next step, when there is one (a PrimaryButton).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return StateMessage(
      icon: icon,
      iconColor: context.colors.onSurfaceMuted,
      title: title,
      message: message,
      action: action,
    );
  }
}
