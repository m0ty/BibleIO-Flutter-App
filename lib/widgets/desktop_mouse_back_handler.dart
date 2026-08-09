import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Turns the auxiliary mouse back button into normal Navigator back behavior
/// on native desktop platforms.
class DesktopMouseBackHandler extends StatelessWidget {
  const DesktopMouseBackHandler({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  bool get _supportsMouseBack {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_supportsMouseBack ||
        event.kind != PointerDeviceKind.mouse ||
        event.buttons & kBackMouseButton == 0) {
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      unawaited(navigator.maybePop());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: child,
    );
  }
}
