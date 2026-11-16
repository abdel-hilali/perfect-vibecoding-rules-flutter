import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/router/app_redirect.dart';
import 'package:kit_app/features/auth/presentation/pages/sign_in_page.dart';
import 'package:kit_app/features/orders/presentation/pages/orders_page.dart';
import 'package:kit_app/features/settings/presentation/pages/settings_page.dart';

String? redirect(String location, {required bool signedIn}) {
  return appRedirect(Uri.parse(location), signedIn: signedIn);
}

String signInWithNext(String next) =>
    Uri(path: SignInPage.path, queryParameters: {nextParam: next}).toString();

void main() {
  group('signed out', () {
    test('an app page goes to sign-in and keeps where the user was going', () {
      expect(
        redirect(OrdersPage.path, signedIn: false),
        signInWithNext(OrdersPage.path),
      );
      expect(
        redirect(SettingsPage.path, signedIn: false),
        signInWithNext(SettingsPage.path),
      );
    });

    test('a deep link keeps its query', () {
      expect(
        redirect('/orders?status=paid', signedIn: false),
        signInWithNext('/orders?status=paid'),
      );
    });

    test('the sign-in page stays, with or without a next', () {
      expect(redirect(SignInPage.path, signedIn: false), isNull);
      expect(
        redirect(signInWithNext(SettingsPage.path), signedIn: false),
        isNull,
      );
    });
  });

  group('signed in', () {
    test('the app pages stay', () {
      expect(redirect(OrdersPage.path, signedIn: true), isNull);
      expect(redirect(SettingsPage.path, signedIn: true), isNull);
    });

    test('the root opens the first tab', () {
      expect(redirect('/', signedIn: true), OrdersPage.path);
    });

    test('sign-in goes back where the user was going', () {
      expect(
        redirect(signInWithNext(SettingsPage.path), signedIn: true),
        SettingsPage.path,
      );
    });

    test('sign-in without a next opens the first tab', () {
      expect(redirect(SignInPage.path, signedIn: true), OrdersPage.path);
    });

    test('a next that leaves the app or loops is ignored', () {
      const unsafe = [
        'https://evil.example.com',
        '//evil.example.com/orders',
        'orders',
        '/sign-in',
        'mailto:a@example.com',
      ];
      for (final next in unsafe) {
        expect(
          redirect(signInWithNext(next), signedIn: true),
          OrdersPage.path,
          reason: next,
        );
      }
    });
  });

  test('safeNext keeps an app path with its query', () {
    expect(safeNext('/orders?status=paid'), '/orders?status=paid');
    expect(safeNext(null), isNull);
  });
}
