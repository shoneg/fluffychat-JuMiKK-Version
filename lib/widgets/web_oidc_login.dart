// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/sign_in_flows/web_oidc_login.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Completes a web redirect before mounting pages that could start another login.
class WebOidcLogin extends StatefulWidget {
  final Widget child;
  final void Function(String location) onNavigate;
  const WebOidcLogin({
    required this.child,
    required this.onNavigate,
    super.key,
  });

  @override
  State<WebOidcLogin> createState() => _WebOidcLoginState();
}

class _WebOidcLoginState extends State<WebOidcLogin> {
  Uri? _callback;
  String? _error;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _callback = takePendingWebOidcLogin();
    if (_callback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finishLogin());
    }
  }

  Future<void> _finishLogin() async {
    if (!mounted) return;
    try {
      final matrix = Matrix.of(context);
      final client = await matrix.getLoginClient();
      await finishWebOidcLogin(client, matrix.store, _callback!);
      if (!mounted) return;
      widget.onNavigate('/backup');
      setState(() => _finished = true);
    } catch (e, s) {
      Logs().w('Unable to complete OIDC login', e, s);
      if (mounted) setState(() => _error = e.toLocalizedString(context));
    }
  }

  void _restartLogin() {
    final hasAccount = Matrix.of(
      context,
    ).widget.clients.any((c) => c.isLogged());
    widget.onNavigate(hasAccount ? '/rooms/settings/addaccount' : '/home');
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_callback == null || _finished) return widget.child;
    return LoginScaffold(
      appBar: AppBar(title: Text(L10n.of(context).login)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _restartLogin,
                      child: Text(L10n.of(context).tryAgain),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
