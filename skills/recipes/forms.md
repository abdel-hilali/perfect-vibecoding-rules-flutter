# Recipe: forms, field errors and a create that runs once

## Problem

Rules written in a widget's `validator:` cannot show the server's answer for a field the same way. A
`TextEditingController` made in `build()` loses the text at every rebuild. A double tap, or a retry after a lost
answer, creates the member twice. The keyboard covers the button, and the context used after the save's `await`
belongs to a page that has closed.

## Rule

- The page owns its `TextEditingController`s: made once in the `State`, disposed in `dispose()` (F15).
- The rules are plain Dart in the domain (`MemberDraft.problems()`), tested without Flutter. The controller keeps
  one problem per field and turns it into the catalog's text; the server's field codes (`email_taken`) become the
  same problems, under the same field (F3, F5, F11).
- Text fields come from the kit (`AppTextField`, F12): a label that stays (a hint vanishes), the error under it.
- One save at a time: the button shows its spinner (`PrimaryButton(isLoading:)`) and a second tap sends nothing.
- A create carries an `Idempotency-Key`, kept while the user retries the same values; new values, new key (F6).
- After the `await`, check `mounted` before the context is used.

## Code

```dart
// lib/features/members/domain/entities/member_draft.dart (not in the starter)
  Map<MemberField, FieldProblem> problems() {
    final name = this.name.trim();
    final email = this.email.trim();
    return {
      if (name.isEmpty)
        MemberField.name: FieldProblem.missing
      else if (name.length > nameMaxLength)
        MemberField.name: FieldProblem.tooLong,
      if (email.isEmpty)
        MemberField.email: FieldProblem.missing
      else if (!_emailShape.hasMatch(email))
        MemberField.email: FieldProblem.invalidEmail,
    };
  }
```

```dart
// lib/features/members/presentation/controllers/invite_member_controller.dart (not in the starter)
    // New values are a new create with a new key; the same values keep the key of the failed try.
    final values = (name: draft.name.trim(), email: draft.email.trim());
    if (values != _sentValues) {
      _sentValues = values;
      _requestKey = randomId();
    }
    _isSaving = true;
    _notify();
    final result = await _inviteMember(draft, requestKey: _requestKey);
    if (_disposed) {
      return false;
    }
    _isSaving = false;
    switch (result) {
      case Success():
        _notify();
        return true;
      case FailureResult(failure: MemberEmailTakenFailure()):
        _problems = {MemberField.email: FieldProblem.taken};
      case FailureResult(:final failure):
        _failure = failure;
    }
```

```dart
// lib/core/common/widgets/app_text_field.dart
        labelText: label,
        labelStyle: text.bodyMuted,
        errorText: error,
        errorStyle: text.caption.copyWith(color: colors.danger),
        // A long message at a large text scale wraps instead of being cut.
        errorMaxLines: 3,
```

```dart
// lib/features/members/presentation/pages/invite_member_page.dart (not in the starter)
  // Widget state, made once and disposed with the page (F15). Made in build(), they would lose the text.
  final _name = TextEditingController();
  final _email = TextEditingController();
  // ...
                  AppTextField(
                    controller: _email,
                    label: l10n.membersEmailLabel,
                    error: controller.problemText(MemberField.email, l10n),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) => controller.edited(MemberField.email),
                    onSubmitted: (_) => unawaited(_submit()),
                  ),
  // ...
  Future<void> _submit() async {
    final controller = NotifierProvider.read<InviteMemberController>(context);
    final draft = MemberDraft(name: _name.text, email: _email.text);
    final done = await controller.submit(draft);
    // The page may have closed while the call ran (F15).
    if (!mounted) {
      return;
    }
```

The fields sit in a `ListView` inside `Expanded`, in an `AutofillGroup`; the `Scaffold` lifts them above the
keyboard. The data source passes the key as `idempotencyKey:` to `ApiClient.create`.

## Traps

- A form in a `Column` without a scroll view overflows the moment the keyboard opens.
  `resizeToAvoidBottomInset: false` hides the button under the keyboard instead.
- `controller.edited(field)` clears that field's old problem as the user types; without it the error stays until
  the next tap.
- A French user types `4,50`: parse numbers with `NumberFormat.decimalPattern(l10n.localeName).parse`, never
  `double.parse`, and send money as whole minor units.
- Keep the email check light (one `@`, a dot after it): the server decides, and a strict pattern refuses real
  addresses.
- `TextInputAction.next` moves the focus to the next field by itself; the last field uses `done` and
  `onSubmitted`.
- A toast only for a problem that belongs to no field.
