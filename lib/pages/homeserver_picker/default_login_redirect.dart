import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:universal_html/html.dart' as html;

class DefaultLoginRedirect extends StatefulWidget {
  const DefaultLoginRedirect({super.key});

  @override
  State<DefaultLoginRedirect> createState() => _DefaultLoginRedirectState();
}

class _DefaultLoginRedirectState extends State<DefaultLoginRedirect> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirectToLogin());
  }

  Future<void> _redirectToLogin() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = await Matrix.of(context).getLoginClient();
      final homeserverInput = AppSettings.defaultHomeserver.value
          .trim()
          .toLowerCase()
          .replaceAll(' ', '-');
      if (homeserverInput.isEmpty) {
        if (!mounted) return;
        context.go('/home/manual');
        return;
      }

      var homeserver = Uri.parse(homeserverInput);
      if (homeserver.scheme.isEmpty) {
        homeserver = Uri.https(homeserverInput, '');
      }

      final (_, _, loginFlows, _) = await client.checkHomeserver(homeserver);
      final supportsSso = loginFlows.any((flow) => flow.type == 'm.login.sso');

      if (!mounted) return;
      if (supportsSso) {
        await _ssoLogin(client);
        if (!mounted) return;
        context.go('/rooms');
      } else {
        final serverLoginTypes = loginFlows.map((flow) => flow.type).join(', ');
        setState(() {
          _error =
              'The configured homeserver does not provide SSO login '
              '(m.login.sso).\n\n'
              'Supported login types: $serverLoginTypes';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = L10n.of(context);
      setState(() {
        _error =
            '${l10n.noConnectionToTheServer}\n'
            '${l10n.tryAgain}\n\n'
            '${e.toLocalizedString(context, ExceptionContext.checkHomeserver)}';
        _loading = false;
      });
    }
  }

  Future<void> _ssoLogin(Client client) async {
    final isDefaultPlatform =
        PlatformInfos.isMobile || PlatformInfos.isWeb || PlatformInfos.isMacOS;
    final redirectUrl = kIsWeb
        ? Uri.parse(
            html.window.location.href,
          ).resolveUri(Uri(pathSegments: ['auth.html'])).toString()
        : isDefaultPlatform
        ? '${AppConfig.appOpenUrlScheme.toLowerCase()}://login'
        : 'http://localhost:3001//login';

    final url = client.homeserver!.replace(
      path: '/_matrix/client/v3/login/sso/redirect',
      queryParameters: {'redirectUrl': redirectUrl},
    );

    final callbackUrlScheme = isDefaultPlatform
        ? Uri.parse(redirectUrl).scheme
        : 'http://localhost:3001';

    final result = await FlutterWebAuth2.authenticate(
      url: url.toString(),
      callbackUrlScheme: callbackUrlScheme,
      options: FlutterWebAuth2Options(useWebview: PlatformInfos.isMobile),
    );
    final token = Uri.parse(result).queryParameters['loginToken'];
    if (token == null || token.isEmpty) {
      throw Exception('Missing login token');
    }

    await client.login(
      LoginType.mLoginToken,
      token: token,
      initialDeviceDisplayName: PlatformInfos.appDisplayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoginScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(L10n.of(context).login),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(L10n.of(context).loadingPleaseWait),
              ] else ...[
                Text(
                  _error ?? L10n.of(context).oopsSomethingWentWrong,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _redirectToLogin,
                  child: Text(L10n.of(context).tryAgain),
                ),
                TextButton(
                  onPressed: () => context.go('/home/manual'),
                  child: Text(L10n.of(context).changeTheHomeserver),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
