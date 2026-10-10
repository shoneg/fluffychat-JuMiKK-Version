// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/oidc_session_json_extension.dart';
import 'package:fluffychat/utils/sign_in_flows/calc_redirect_url.dart';
import 'package:fluffychat/utils/sign_in_flows/oidc_callback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> oidcLoginFlow(
  Client client,
  BuildContext context,
  bool signUp,
) async {
  Logs().i('Starting Matrix Native OIDC Flow...');

  final (redirectUrl, urlScheme) = calcRedirectUrl();

  final clientUri = Uri.parse(AppSettings.website.value);
  final supportWebPlatform =
      kIsWeb &&
      redirectUrl.scheme == 'https' &&
      isSameHostOrSubdomain(redirectUrl, clientUri);
  if (kIsWeb && redirectUrl.scheme == 'https' && !supportWebPlatform) {
    throw StateError(
      'The web app must be hosted on ${clientUri.host} or one of its subdomains.',
    );
  }
  if (kIsWeb && !supportWebPlatform) {
    Logs().w(
      'OIDC Application Type web is not supported. Using native now. Please use this instance not in production!',
    );
  }

  final oidcClientData = await client.registerOidcClient(
    redirectUris: [redirectUrl],
    applicationType: supportWebPlatform
        ? OidcApplicationType.web
        : OidcApplicationType.native,
    clientInformation: OidcClientInformation(
      clientName: AppSettings.applicationName.value,
      clientUri: clientUri,
      logoUri: _optionalMetadataUri(AppSettings.logoUrl.value),
      tosUri: _optionalMetadataUri(AppSettings.tos.value),
      policyUri: _optionalMetadataUri(AppSettings.privacyPolicy.value),
    ),
  );

  final session = await client.initOidcLoginSession(
    oidcClientData: oidcClientData,
    redirectUri: redirectUrl,
    prompt: signUp ? 'create' : null,
  );

  if (!context.mounted) return;

  if (kIsWeb) {
    final store = await SharedPreferences.getInstance();
    await store.setString(
      OidcSessionJsonExtension.homeserverStoreKey,
      client.homeserver!.toString(),
    );
    await store.setString(
      OidcSessionJsonExtension.storeKey,
      jsonEncode(session.toJson()),
    );
  }

  final returnUrlString = await FlutterWebAuth2.authenticate(
    url: session.authenticationUri.toString(),
    callbackUrlScheme: urlScheme,
    options: FlutterWebAuth2Options(useWebview: false, windowName: '_self'),
  );
  if (kIsWeb) return; // WebOidcLogin completes the redirect after app startup.

  final response = parseOidcCallback(
    Uri.parse(returnUrlString),
    expectedState: session.state,
  );
  await client.oidcLogin(
    session: session,
    code: response.code,
    state: response.state,
  );
}

Uri? _optionalMetadataUri(String value) =>
    value.trim().isEmpty ? null : Uri.parse(value.trim());
