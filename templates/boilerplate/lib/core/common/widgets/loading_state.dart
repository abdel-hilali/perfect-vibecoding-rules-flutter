import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:material_ui/material_ui.dart';

/// The loading state of a data screen (F12): a spinner in the brand colour, announced to screen readers.
///
/// It spins forever, so a widget test that shows it uses `pump()`, never `pumpAndSettle()` (which would time out).
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: context.l10n.commonLoading,
        child: CircularProgressIndicator(color: context.colors.primary),
      ),
    );
  }
}
