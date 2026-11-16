import 'package:go_router/go_router.dart';
import 'package:kit_app/core/common/widgets/notifier_provider.dart';
import 'package:kit_app/core/config/injection-modules/settings_module.dart';
import 'package:kit_app/features/settings/presentation/controllers/settings_controller.dart';
import 'package:kit_app/features/settings/presentation/pages/settings_page.dart';

/// The routes of the settings feature (F7).
List<RouteBase> settingsRoutes() {
  return [
    GoRoute(
      path: SettingsPage.path,
      name: SettingsPage.name,
      builder: (context, state) {
        // App-wide: App reads the same controller for the theme and the locale, so the page must not dispose it.
        return NotifierProvider<SettingsController>(
          create: () => SettingsModule.instance.settingsController,
          autoDispose: false,
          child: const SettingsPage(),
        );
      },
    ),
  ];
}
