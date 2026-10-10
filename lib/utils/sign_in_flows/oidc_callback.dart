// SPDX-License-Identifier: AGPL-3.0-or-later

const _oidcResponseKeys = {
  'code',
  'state',
  'error',
  'error_description',
  'error_uri',
};

/// Supports OAuth fragment responses as well as query responses and router URLs.
Map<String, String> oidcCallbackParameters(Uri uri) {
  final fragment = uri.fragment;
  final fragmentQuery = fragment.contains('?')
      ? fragment.substring(fragment.indexOf('?') + 1)
      : fragment;
  final fragmentParameters = Uri.splitQueryString(fragmentQuery);
  if (fragmentParameters.containsKey('code') ||
      fragmentParameters.containsKey('error')) {
    return fragmentParameters;
  }
  return uri.queryParameters;
}

({String code, String state}) parseOidcCallback(
  Uri uri, {
  required String expectedState,
}) {
  final parameters = oidcCallbackParameters(uri);
  final state = parameters['state'];
  if (state == null || state.isEmpty || state != expectedState) {
    throw const FormatException(
      'The login response does not match this session.',
    );
  }
  final error = parameters['error'];
  if (error != null) {
    throw FormatException(parameters['error_description'] ?? error);
  }
  final code = parameters['code'];
  if (code == null || code.isEmpty) {
    throw const FormatException(
      'The server did not return an authorization code.',
    );
  }
  return (code: code, state: state);
}

/// Removes the authorization response before the router and logging see it.
Uri withoutOidcCallbackParameters(Uri uri) {
  final query = Map<String, String>.of(uri.queryParameters)
    ..removeWhere((key, _) => _oidcResponseKeys.contains(key));
  final fragment = uri.fragment;
  final fragmentParameters = Uri.splitQueryString(
    fragment.contains('?')
        ? fragment.substring(fragment.indexOf('?') + 1)
        : fragment,
  );
  var cleanFragment = fragment;
  if (fragmentParameters.keys.any(_oidcResponseKeys.contains)) {
    if (fragment.startsWith('/')) {
      fragmentParameters.removeWhere(
        (key, _) => _oidcResponseKeys.contains(key),
      );
      cleanFragment = fragment.split('?').first;
      if (fragmentParameters.isNotEmpty) {
        cleanFragment += '?${Uri(queryParameters: fragmentParameters).query}';
      }
    } else {
      cleanFragment = '';
    }
  }
  final baseUri = Uri.parse(uri.removeFragment().toString().split('?').first);
  return baseUri.replace(
    queryParameters: query.isEmpty ? null : query,
    fragment: cleanFragment.isEmpty ? null : cleanFragment,
  );
}

bool isSameHostOrSubdomain(Uri uri, Uri clientUri) =>
    uri.host == clientUri.host || uri.host.endsWith('.${clientUri.host}');
