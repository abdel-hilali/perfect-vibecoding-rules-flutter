import 'package:kit_app/core/common/widgets/primary_button.dart';
import 'package:kit_app/core/common/widgets/state_message.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_icons.dart';
import 'package:material_ui/material_ui.dart';

/// The error state of a data screen (F12): a translated message and a retry. Never a stack trace, a URL or the
/// server's own text (F5): the controller turns the Failure into [message].
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StateMessage(
      icon: AppIcons.error,
      iconColor: context.colors.danger,
      title: l10n.commonErrorTitle,
      message: message,
      action: PrimaryButton(
        label: l10n.commonRetry,
        icon: AppIcons.retry,
        onPressed: onRetry,
      ),
    );
  }
}
