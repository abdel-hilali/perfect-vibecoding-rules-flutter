import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kit_app/core/common/widgets/show_app_toast.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_theme.dart';
import 'package:kit_app/core/theme/system_bars.dart';
import 'package:kit_app/features/settings/presentation/controllers/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The App widget: MaterialApp.router with both themes, the user's theme mode and language, the catalogs, and
/// the system bars that follow the theme (F8, F9, F11).
class App extends StatefulWidget {
  const App({super.key, required this.router, required this.settings});

  final GoRouter router;
  final SettingsController settings;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  // Built once: a new ThemeData on every rebuild would make MaterialApp compare and animate for nothing.
  final ThemeData _light = AppTheme.light();
  final ThemeData _dark = AppTheme.dark();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_applySystemBars);
    _applySystemBars();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_applySystemBars);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _applySystemBars();

  // SystemChrome at start and on every theme change (F9). The AnnotatedRegion below covers every drawn frame;
  // this covers the moment before the first one and the switch itself.
  void _applySystemBars() {
    final phoneIsDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final dark = switch (widget.settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => phoneIsDark,
    };
    SystemChrome.setSystemUIOverlayStyle(
      systemOverlayFor(dark ? AppColors.dark : AppColors.light),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        return MaterialApp.router(
          routerConfig: widget.router,
          onGenerateTitle: (context) => context.l10n.appTitle,
          scaffoldMessengerKey: appMessengerKey,
          theme: _light,
          darkTheme: _dark,
          themeMode: widget.settings.themeMode,
          locale: widget.settings.locale,
          // material_ui's delegates, not AppLocalizations.localizationsDelegates: gen-l10n still lists the
          // flutter_localizations ones, deprecated since Flutter 3.47 and unseen by material_ui widgets.
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // Never one SafeArea here (F9): every page paints its own colour edge to edge.
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: systemOverlayFor(context.colors),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
