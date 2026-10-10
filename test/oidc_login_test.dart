// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/oidc_session_json_extension.dart';
import 'package:fluffychat/utils/sign_in_flows/oidc_callback.dart';
import 'package:fluffychat/utils/sign_in_flows/web_oidc_login.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/web_oidc_login.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OIDC callback', () {
    for (final url in [
      'de.jumikk.chat.auth:/login?code=auth%2Bcode&state=expected',
      'https://chat.jumikk.de/#code=auth%2Bcode&state=expected',
      'https://chat.jumikk.de/#?code=auth%2Bcode&state=expected',
      'https://chat.jumikk.de/#/home?code=auth%2Bcode&state=expected',
      'https://chat.jumikk.de/?code=auth%2Bcode&state=expected#/home',
    ]) {
      test('Reads the authorization response from $url', () {
        final response = parseOidcCallback(
          Uri.parse(url),
          expectedState: 'expected',
        );
        expect(response, (code: 'auth+code', state: 'expected'));
      });
    }

    test('Rejects missing, empty, or mismatched state', () {
      for (final query in [
        'code=code',
        'code=code&state=',
        'code=code&state=other',
      ]) {
        expect(
          () => parseOidcCallback(
            Uri.parse('de.jumikk.chat.auth:/login?$query'),
            expectedState: 'expected',
          ),
          throwsFormatException,
        );
      }
    });

    test('Reports a rejected authorization and requires a code', () {
      expect(
        () => parseOidcCallback(
          Uri.parse(
            'https://chat.jumikk.de/#error=access_denied&state=expected',
          ),
          expectedState: 'expected',
        ),
        throwsFormatException,
      );
      expect(
        () => parseOidcCallback(
          Uri.parse('https://chat.jumikk.de/?state=expected'),
          expectedState: 'expected',
        ),
        throwsFormatException,
      );
    });

    test('Removes authorization parameters while preserving normal routing', () {
      expect(
        withoutOidcCallbackParameters(
          Uri.parse(
            'https://chat.jumikk.de/app/?lang=de&code=secret&state=expected#/home',
          ),
        ).toString(),
        'https://chat.jumikk.de/app/?lang=de#/home',
      );
      expect(
        withoutOidcCallbackParameters(
          Uri.parse('https://chat.jumikk.de/app/#code=secret&state=expected'),
        ).toString(),
        'https://chat.jumikk.de/app/',
      );
      expect(
        withoutOidcCallbackParameters(
          Uri.parse(
            'https://chat.jumikk.de/app/#/home?code=secret&state=expected&lang=de',
          ),
        ).toString(),
        'https://chat.jumikk.de/app/#/home?lang=de',
      );
      final roomLink = Uri.parse(
        'https://chat.jumikk.de/#/rooms?event=message',
      );
      expect(withoutOidcCallbackParameters(roomLink), roomLink);
    });
  });

  test('OIDC domains must match on a hostname boundary', () {
    final clientUri = Uri.parse('https://jumikk.de');
    expect(
      isSameHostOrSubdomain(Uri.parse('https://jumikk.de/app/'), clientUri),
      isTrue,
    );
    expect(
      isSameHostOrSubdomain(Uri.parse('https://chat.jumikk.de/'), clientUri),
      isTrue,
    );
    expect(
      isSameHostOrSubdomain(Uri.parse('https://notjumikk.de/'), clientUri),
      isFalse,
    );
    expect(
      isSameHostOrSubdomain(
        Uri.parse('https://jumikk.de.example.org/'),
        clientUri,
      ),
      isFalse,
    );
  });

  test(
    'An invalid web callback clears the pending session before any network call',
    () async {
      final session = OidcLoginSession(
        oidcClientData: OidcClientData.fromJson({
          'client_id': 'registered-client',
          'client_name': 'JuMiKK-Chat',
          'client_uri': 'https://jumikk.de',
        }),
        authenticationUri: Uri.parse('https://accounts.jumikk.de/authorize'),
        redirectUri: Uri.parse('https://chat.jumikk.de/'),
        codeVerifier: 'verifier',
        state: 'expected',
      );
      SharedPreferences.setMockInitialValues({
        OidcSessionJsonExtension.storeKey: jsonEncode(session.toJson()),
        OidcSessionJsonExtension.homeserverStoreKey: 'https://server.invalid',
      });
      final store = await SharedPreferences.getInstance();
      final client = Client('OIDC callback test', database: _UnusedDatabase());
      await expectLater(
        finishWebOidcLogin(
          client,
          store,
          Uri.parse('https://chat.jumikk.de/#code=code&state=other'),
        ),
        throwsFormatException,
      );
      expect(store.containsKey(OidcSessionJsonExtension.storeKey), isFalse);
      expect(
        store.containsKey(OidcSessionJsonExtension.homeserverStoreKey),
        isFalse,
      );
      expect(client.homeserver, isNull);
    },
  );

  testWidgets('Web login handles a failed callback before mounting the app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppSettings.init(loadWebConfigFile: false);
    final client = Client('Web login widget test', database: _UnusedDatabase());
    final matrix = _TestMatrixState(client, store);
    final navigations = <String>[];
    prepareWebOidcLogin(
      Uri.parse('https://chat.jumikk.de/#code=code&state=state'),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          ...L10n.localizationsDelegates,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: L10n.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Provider<MatrixState>.value(
          value: matrix,
          child: WebOidcLogin(
            onNavigate: navigations.add,
            child: const Text('Normal app'),
          ),
        ),
      ),
    );
    expect(find.text('Normal app'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Normal app'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(navigations, ['/home']);
    expect(find.text('Normal app'), findsOneWidget);
  });
}

class _UnusedDatabase extends Fake implements DatabaseApi {}

class _TestMatrixState extends Fake implements MatrixState {
  @override
  final Client client;
  @override
  final SharedPreferences store;
  _TestMatrixState(this.client, this.store);

  @override
  Matrix get widget => Matrix(clients: [client], store: store);

  @override
  Future<Client> getLoginClient() async => client;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'Test Matrix state';
}
