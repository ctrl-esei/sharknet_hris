import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class SessionTrackingService
    with WidgetsBindingObserver {
  SessionTrackingService._();

  static final SessionTrackingService instance =
      SessionTrackingService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  Timer? _heartbeatTimer;
  bool _observingLifecycle = false;
  String _role = 'user';

  Future<void> start({
    String role = 'user',
  }) async {
    _role = role.trim().isEmpty
        ? 'user'
        : role.trim().toLowerCase();

    if (!_observingLifecycle) {
      WidgetsBinding.instance
          .addObserver(this);
      _observingLifecycle = true;
    }

    await _writeSession(
      isOnline: true,
      includeSignedInAt: true,
    );

    _startHeartbeat();
  }

  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _writeSession(
      isOnline: false,
    );

    if (_observingLifecycle) {
      WidgetsBinding.instance
          .removeObserver(this);
      _observingLifecycle = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        unawaited(
          _writeSession(
            isOnline: true,
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();

      unawaited(
        _writeSession(
          isOnline: true,
        ),
      );
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      unawaited(
        _writeSession(
          isOnline: false,
        ),
      );
    }
  }

  Future<void> _writeSession({
    required bool isOnline,
    bool includeSignedInAt = false,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    Map<String, dynamic> profile =
        <String, dynamic>{};

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          userDocument = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      profile = userDocument.data() ??
          <String, dynamic>{};
    } catch (_) {}

    final Map<String, dynamic> update =
        <String, dynamic>{
      'userId': user.uid,
      'fullName': _text(
        profile['fullName'] ??
            user.displayName,
        fallback: 'Authenticated User',
      ),
      'email': _text(
        profile['email'] ?? user.email,
        fallback: '',
      ),
      'role': _text(
        profile['userRole'] ??
            profile['role'] ??
            _role,
        fallback: _role,
      ),
      'platform': _platformName(),
      'isOnline': isOnline,
      'lastActiveAt':
          FieldValue.serverTimestamp(),
      'updatedAt':
          FieldValue.serverTimestamp(),
    };

    if (includeSignedInAt) {
      update['signedInAt'] =
          FieldValue.serverTimestamp();
    }

    await _firestore
        .collection('user_sessions')
        .doc(user.uid)
        .set(
      update,
      SetOptions(merge: true),
    );
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}

String _text(
  dynamic value, {
  required String fallback,
}) {
  final String text =
      value?.toString().trim() ?? '';

  return text.isEmpty ? fallback : text;
}
