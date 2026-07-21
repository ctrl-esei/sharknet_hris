import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InactivityLogoutWrapper
    extends StatefulWidget {
  const InactivityLogoutWrapper({
    required this.child,
    super.key,
    this.idleTimeout =
        const Duration(minutes: 10),
    this.onBeforeLogout,
  });

  final Widget child;
  final Duration idleTimeout;
  final Future<void> Function()?
      onBeforeLogout;

  @override
  State<InactivityLogoutWrapper>
      createState() =>
          _InactivityLogoutWrapperState();
}

class _InactivityLogoutWrapperState
    extends State<InactivityLogoutWrapper>
    with WidgetsBindingObserver {
  Timer? _idleTimer;

  DateTime _lastActivity =
      DateTime.now();

  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addObserver(this);

    _resetTimer();
  }

  void _registerActivity() {
    _lastActivity = DateTime.now();
    _resetTimer();
  }

  void _resetTimer() {
    _idleTimer?.cancel();

    _idleTimer = Timer(
      widget.idleTimeout,
      _logoutForInactivity,
    );
  }

  Future<void> _logoutForInactivity()
      async {
    if (_loggingOut ||
        FirebaseAuth.instance.currentUser ==
            null) {
      return;
    }

    _loggingOut = true;

    try {
      await widget.onBeforeLogout?.call();
      await FirebaseAuth.instance.signOut();
    } finally {
      _loggingOut = false;
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state ==
        AppLifecycleState.resumed) {
      final Duration idleDuration =
          DateTime.now().difference(
        _lastActivity,
      );

      if (idleDuration >=
          widget.idleTimeout) {
        _logoutForInactivity();
      } else {
        _resetTimer();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    _idleTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior:
          HitTestBehavior.translucent,
      onPointerDown: (_) =>
          _registerActivity(),
      onPointerMove: (_) =>
          _registerActivity(),
      onPointerSignal: (_) =>
          _registerActivity(),
      child: widget.child,
    );
  }
}
