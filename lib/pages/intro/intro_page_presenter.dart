// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/pages/intro/intro_page.dart';
import 'package:fluffychat/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:fluffychat/utils/sign_in_flows/check_homeserver.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class IntroPagePresenter extends StatefulWidget {
  const IntroPagePresenter({super.key});

  @override
  State<IntroPagePresenter> createState() => _IntroPagePresenterState();
}

class _IntroPagePresenterState extends State<IntroPagePresenter> {
  void _login() {
    final presetHomeserver = AppSettings.presetHomeserver.value;
    if (presetHomeserver.isEmpty) {
      context.go('${GoRouterState.of(context).uri.path}/sign_in');
      return;
    }

    connectToHomeserverFlow(
      PublicHomeserverData(name: presetHomeserver),
      context,
      (snapshot) {},
      false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IntroPage(
      isLoading: false,
      loggingInToHomeserver: null,
      hasPresetHomeserver: AppSettings.presetHomeserver.value.isNotEmpty,
      welcomeText: AppSettings.welcomeText.value.isEmpty
          ? null
          : AppSettings.welcomeText.value,
      login: _login,
    );
  }
}
