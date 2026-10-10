// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/utils/matrix_sdk_extensions/oidc_session_json_extension.dart';
import 'package:fluffychat/utils/sign_in_flows/oidc_callback.dart';
import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

Uri? _pendingWebOidcCallback;

/// Capture before GoRouter can replace the URL or interpret the OAuth fragment.
void capturePendingWebOidcLogin() {
  if (!kIsWeb) return;
  final uri = Uri.parse(html.window.location.href);
  final cleanUri = prepareWebOidcLogin(uri);
  if (cleanUri == null) return;
  html.window.history.replaceState(null, '', cleanUri.toString());
}

/// Stages a callback for the shared startup handler and returns the clean URL.
Uri? prepareWebOidcLogin(Uri uri) {
  final parameters = oidcCallbackParameters(uri);
  if (!parameters.containsKey('code') && !parameters.containsKey('error')) {
    return null;
  }
  _pendingWebOidcCallback = uri;
  return withoutOidcCallbackParameters(uri);
}

Uri? takePendingWebOidcLogin() {
  final uri = _pendingWebOidcCallback;
  _pendingWebOidcCallback = null;
  return uri;
}

Future<void> finishWebOidcLogin(
  Client client,
  SharedPreferences store,
  Uri callbackUri,
) async {
  try {
    final homeserver = store.getString(
      OidcSessionJsonExtension.homeserverStoreKey,
    );
    final storedSession = store.getString(OidcSessionJsonExtension.storeKey);
    if (homeserver == null || storedSession == null) {
      throw const FormatException(
        'No pending login session was found. Please sign in again.',
      );
    }
    final session = OidcSessionJsonExtension.fromJson(
      jsonDecode(storedSession) as Map<String, Object?>,
    );
    final response = parseOidcCallback(
      callbackUri,
      expectedState: session.state,
    );
    await client.checkHomeserver(
      Uri.parse(homeserver),
      fetchAuthMetadata: true,
    );
    await client.oidcLogin(
      session: session,
      code: response.code,
      state: response.state,
    );
  } finally {
    await store.remove(OidcSessionJsonExtension.storeKey);
    await store.remove(OidcSessionJsonExtension.homeserverStoreKey);
  }
}
