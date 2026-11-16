import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_radius.dart';
import 'package:kit_app/core/theme/app_text_styles.dart';
import 'package:material_ui/material_ui.dart';

/// The app's text field (F12): its label and error come from the catalog, its colours from the tokens.
///
/// The page owns the TextEditingController (created once, disposed with the page). The screen's controller owns
/// the rules and says which [error] to show, so the server's answer for a field shows the same way.
///
/// The [label] stays above the text once the user types, and it is the field's name for a screen reader; a hint
/// would vanish at the first letter. The field is never dense, so it stays at least 48 dp tall (F16).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;

  /// The field's problem in the user's words; null shows none.
  final String? error;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: AppRadius.card,
      borderSide: BorderSide(color: color),
    );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: text.body,
      cursorColor: colors.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: text.bodyMuted,
        errorText: error,
        errorStyle: text.caption.copyWith(color: colors.danger),
        // A long message at a large text scale wraps instead of being cut.
        errorMaxLines: 3,
        filled: true,
        fillColor: colors.surfaceRaised,
        enabledBorder: border(colors.outline),
        focusedBorder: border(colors.primary),
        errorBorder: border(colors.danger),
        focusedErrorBorder: border(colors.danger),
      ),
    );
  }
}
