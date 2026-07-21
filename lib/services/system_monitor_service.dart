import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SystemMonitorService {
  SystemMonitorService._();

  static final SystemMonitorService instance =
      SystemMonitorService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  Timer? _monitorTimer;
  bool _checkRunning = false;

  void startMonitoring() {
    unawaited(runHealthChecks());

    _monitorTimer?.cancel();

    _monitorTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        unawaited(runHealthChecks());
      },
    );
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  Future<void> runHealthChecks() async {
    if (_checkRunning) {
      return;
    }

    _checkRunning = true;

    try {
      await _checkAuthentication();
      await _checkFirestore();
      await _checkFaceRecognitionData();
      await _checkApplicationConnectivity();
    } finally {
      _checkRunning = false;
    }
  }

  Future<void> _checkAuthentication() async {
    final Stopwatch stopwatch =
        Stopwatch()..start();

    String status = 'online';
    String message =
        'Authenticated session is available.';

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        status = 'warning';
        message =
            'No authenticated user is available.';
      } else {
        await user.reload();
      }
    } catch (error) {
      status = 'offline';
      message =
          'Authentication check failed: $error';
    }

    stopwatch.stop();

    await _recordHealth(
      id: 'authentication',
      serviceName:
          'Authentication Service',
      description:
          'Firebase Authentication session check',
      status: status,
      responseMs:
          stopwatch.elapsedMilliseconds,
      message: message,
      sortOrder: 1,
    );
  }

  Future<void> _checkFirestore() async {
    final Stopwatch stopwatch =
        Stopwatch()..start();

    String status = 'online';
    String message =
        'Firestore responded successfully.';

    try {
      await _firestore
          .collection('users')
          .limit(1)
          .get(
            const GetOptions(
              source: Source.server,
            ),
          );
    } catch (error) {
      status = 'offline';
      message =
          'Firestore check failed: $error';
    }

    stopwatch.stop();

    await _recordHealth(
      id: 'firestore',
      serviceName:
          'Firestore Database',
      description:
          'Cloud Firestore read availability',
      status: status,
      responseMs:
          stopwatch.elapsedMilliseconds,
      message: message,
      sortOrder: 2,
    );
  }

  Future<void> _checkFaceRecognitionData() async {
    final Stopwatch stopwatch =
        Stopwatch()..start();

    String status = 'online';
    String message =
        'Registered face profiles are available.';

    try {
      final QuerySnapshot<Map<String, dynamic>>
          snapshot = await _firestore
              .collection('employee')
              .where(
                'faceRegistered',
                isEqualTo: true,
              )
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        status = 'warning';
        message =
            'No registered employee face profile was found.';
      }
    } catch (error) {
      status = 'offline';
      message =
          'Face-profile check failed: $error';
    }

    stopwatch.stop();

    await _recordHealth(
      id: 'face_recognition',
      serviceName:
          'Face Recognition Data',
      description:
          'Registered biometric profile availability',
      status: status,
      responseMs:
          stopwatch.elapsedMilliseconds,
      message: message,
      sortOrder: 3,
    );
  }

  Future<void>
      _checkApplicationConnectivity() async {
    final Stopwatch stopwatch =
        Stopwatch()..start();

    String status = 'online';
    String message =
        'Application connectivity is operational.';

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        status = 'warning';
        message =
            'Connectivity check skipped because no user is signed in.';
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .get(
              const GetOptions(
                source: Source.server,
              ),
            );
      }
    } catch (error) {
      status = 'offline';
      message =
          'Application connectivity check failed: $error';
    }

    stopwatch.stop();

    await _recordHealth(
      id: 'application_connectivity',
      serviceName:
          'Application Connectivity',
      description:
          'Authenticated application-to-Firebase connection',
      status: status,
      responseMs:
          stopwatch.elapsedMilliseconds,
      message: message,
      sortOrder: 4,
    );
  }

  Future<void> _recordHealth({
    required String id,
    required String serviceName,
    required String description,
    required String status,
    required int responseMs,
    required String message,
    required int sortOrder,
  }) async {
    await _firestore
        .collection('system_health')
        .doc(id)
        .set(
      <String, dynamic>{
        'serviceName': serviceName,
        'description': description,
        'status': status,
        'averageResponseMs':
            responseMs.toDouble(),
        'message': message,
        'sortOrder': sortOrder,
        'lastCheckedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
