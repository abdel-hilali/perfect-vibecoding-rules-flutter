import 'package:kit_app/core/common/widgets/app_top_bar.dart';
import 'package:kit_app/core/common/widgets/notifier_provider.dart';
import 'package:kit_app/core/common/widgets/show_app_toast.dart';
import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_spacing.dart';
import 'package:kit_app/features/settings/domain/entities/theme_choice.dart';
import 'package:kit_app/features/settings/presentation/controllers/settings_controller.dart';
import 'package:kit_app/features/settings/presentation/widgets/choice_tile.dart';
import 'package:kit_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:material_ui/material_ui.dart';

/// The settings tab: the theme (system, light, dark) and the language, both saved on the device.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const path = '/settings';
  static const name = 'settings';

  @override
  Widget build(BuildContext context) {
    final controller = NotifierProvider.of<SettingsController>(context);
    final l10n = context.l10n;
    final themes = {
      ThemeChoice.system: l10n.settingsThemeSystem,
      ThemeChoice.light: l10n.settingsThemeLight,
      ThemeChoice.dark: l10n.settingsThemeDark,
    };
    // Each language is named in its own language, so a user lost in the wrong one still finds theirs.
    final languages = <String?, String>{
      null: l10n.settingsLanguageSystem,
      'en': l10n.settingsLanguageEnglish,
      'fr': l10n.settingsLanguageFrench,
      'ar': l10n.settingsLanguageArabic,
    };
    return Scaffold(
      body: Column(
        children: [
          AppTopBar(title: l10n.settingsTitle),
          Expanded(
            child: ListView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                SettingsSection(
                  title: l10n.settingsThemeSection,
                  children: [
                    for (final MapEntry(key: choice, value: label)
                        in themes.entries)
                      ChoiceTile(
                        label: label,
                        selected: controller.themeChoice == choice,
                        onTap: () =>
                            _save(context, controller.setThemeChoice(choice)),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SettingsSection(
                  title: l10n.settingsLanguageSection,
                  children: [
                    for (final MapEntry(key: code, value: label)
                        in languages.entries)
                      ChoiceTile(
                        label: label,
                        selected: controller.languageCode == code,
                        onTap: () =>
                            _save(context, controller.setLanguage(code)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The choice already shows; only a failed save is worth a word.
  static Future<void> _save(
    BuildContext context,
    Future<Failure?> saving,
  ) async {
    final failure = await saving;
    // After an await the page may be gone, and its context with it (F15).
    if (failure == null || !context.mounted) {
      return;
    }
    showAppToast(context.l10n.settingsSaveFailed);
  }
}
