import 'package:kit_app/core/common/widgets/app_top_bar.dart';
import 'package:kit_app/core/common/widgets/empty_state.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_icons.dart';
import 'package:material_ui/material_ui.dart';

/// Where the signed-out gate sends the user (F7).
///
/// The app has no sign-in yet (SessionModule.useFakeAccount), so this is a real, guarded route with a "coming
/// soon" body, never a 404 behind the redirect. The auth feature grows here: a controller, a use case, a
/// repository, an auth module.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  static const path = '/sign-in';
  static const name = 'sign-in';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Column(
        children: [
          AppTopBar(title: l10n.authSignInTitle, showBack: false),
          Expanded(
            child: EmptyState(
              icon: AppIcons.signIn,
              title: l10n.authSignInSoonTitle,
              message: l10n.authSignInSoonBody,
            ),
          ),
        ],
      ),
    );
  }
}
