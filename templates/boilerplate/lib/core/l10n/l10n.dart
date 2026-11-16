import 'package:flutter/widgets.dart';
import 'package:kit_app/core/l10n/generated/app_localizations.dart';

// Pages import this one file for both the extension and the generated class.
export 'package:kit_app/core/l10n/generated/app_localizations.dart';

extension L10nContext on BuildContext {
  /// The catalog of the locale in force here (F11): `context.l10n.ordersEmptyTitle`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
