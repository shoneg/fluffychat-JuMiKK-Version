import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/sign_in_flows/oidc_login.dart';
import 'package:fluffychat/utils/sign_in_flows/sso_login.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

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

      final (_, _, loginFlows, authMetadata) = await client.checkHomeserver(
        homeserver,
        fetchAuthMetadata: true,
      );
      final supportsSso = loginFlows.any((flow) => flow.type == 'm.login.sso');

      if (!mounted) return;
      if (authMetadata != null && AppSettings.enableMatrixNativeOIDC.value) {
        await oidcLoginFlow(client, context, false);
      } else if (supportsSso) {
        await ssoLoginFlow(client, context, false, loginFlows);
      } else {
        throw BadServerLoginTypesException(
          loginFlows.map((flow) => flow.type).toSet(),
          {'m.login.sso', 'OAuth 2.0 / OIDC'},
        );
      }

      // A web OIDC redirect is completed after the app reloads. A canceled
      // provider selection also must not navigate to a logged-in page.
      if (!client.isLogged()) {
        if (!mounted) return;
        setState(() {
          _error = L10n.of(context).theProcessWasCanceled;
          _loading = false;
        });
        return;
      }
      await AppSettings.defaultHomeserver.setItem(homeserverInput);
      if (mounted) context.go('/backup');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toLocalizedString(context, ExceptionContext.checkHomeserver);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginScaffold(
      appBar: AppBar(centerTitle: true, title: Text(L10n.of(context).login)),
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
