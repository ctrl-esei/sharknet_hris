import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/attendance_policy.dart';
import '../../services/face_recognition_service.dart';

enum AttendanceAction { timeIn, timeOut }

class FaceAttendanceScreen extends StatefulWidget {
  const FaceAttendanceScreen({super.key});

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;

  bool _isInitializing = true;
  bool _isScanning = false;
  bool _isEmployeeRestricted = false;

  String? _errorMessage;
  String? _expectedEmployeeId;
  String? _expectedEmployeeName;

  AttendanceAction? _selectedAction;

  String _statusMessage = 'Preparing secure face attendance...';

  FaceMatchResult? _lastMatch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareScreen();
  }

  Future<void> _prepareScreen() async {
    try {
      await _loadAccessContext();

      if (!mounted) {
        return;
      }

      final bool accepted = await _showAttendanceNotice();

      if (!mounted) {
        return;
      }

      if (!accepted) {
        Navigator.of(context).pop();
        return;
      }

      await _initializeCamera();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _loadAccessContext() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Your login session has expired. Please sign in again.');
    }

    final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    if (!userSnapshot.exists) {
      throw StateError('The signed-in user profile was not found.');
    }

    final Map<String, dynamic> data =
        userSnapshot.data() ?? <String, dynamic>{};

    final String role =
        (data['userRole'] ?? data['role'])?.toString().trim().toLowerCase() ??
        '';

    _isEmployeeRestricted = role == 'employee';

    if (!_isEmployeeRestricted) {
      return;
    }

    final String employeeId = _referenceId(data['employeeId']);

    if (employeeId.isEmpty) {
      throw StateError(
        'The signed-in employee account has no linked employee record.',
      );
    }

    final DocumentReference<Map<String, dynamic>> directReference =
        FirebaseFirestore.instance.collection('employee').doc(employeeId);

    DocumentSnapshot<Map<String, dynamic>> employeeSnapshot =
        await directReference.get();

    DocumentReference<Map<String, dynamic>> employeeReference = directReference;

    if (!employeeSnapshot.exists) {
      final QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore
          .instance
          .collection('employee')
          .where('employeeId', isEqualTo: employeeId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw StateError('No employee profile matches "$employeeId".');
      }

      employeeReference = query.docs.first.reference;
      employeeSnapshot = query.docs.first;
    }

    final Map<String, dynamic> employeeData =
        employeeSnapshot.data() ?? <String, dynamic>{};

    _expectedEmployeeId = employeeReference.id;
    _expectedEmployeeName =
        employeeData['fullName']?.toString().trim().isNotEmpty == true
        ? employeeData['fullName'].toString().trim()
        : employeeReference.id.toUpperCase();

    _selectedAction = await _recommendedAction(employeeReference.id);
  }

  Future<AttendanceAction> _recommendedAction(String employeeId) async {
    final DateTime now = DateTime.now();
    final String dateKey = _dateKey(now);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('attendance')
            .doc('${employeeId}_$dateKey')
            .get();

    final Map<String, dynamic>? existing = snapshot.data();

    final DateTime? timeIn = _dateTimeFromValue(existing?['timeIn']);

    final DateTime? timeOut = _dateTimeFromValue(existing?['timeOut']);

    if (timeIn == null) {
      return AttendanceAction.timeIn;
    }

    if (timeOut == null) {
      return AttendanceAction.timeOut;
    }

    throw StateError('Your attendance is already completed for today.');
  }

  Future<bool> _showAttendanceNotice() async {
    bool understood = false;

    AttendanceAction selected = _selectedAction ?? AttendanceAction.timeIn;

    final bool? accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  title: const Row(
                    children: <Widget>[
                      Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF1565C0),
                      ),
                      SizedBox(width: 10),
                      Expanded(child: Text('Face Attendance')),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (_isEmployeeRestricted)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF5FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Account-bound verification: only the '
                              'registered face of '
                              '${_expectedEmployeeName ?? 'this employee'} '
                              'will be accepted.',
                              style: const TextStyle(
                                color: Color(0xFF1849A9),
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        if (_isEmployeeRestricted) const SizedBox(height: 14),
                        const Text(
                          'Choose the attendance action:',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        RadioGroup<AttendanceAction>(
                          groupValue: selected,
                          onChanged: (AttendanceAction? value) {
                            if (value == null) {
                              return;
                            }

                            setDialogState(() {
                              selected = value;
                            });
                          },
                          child: const Column(
                            children: <Widget>[
                              RadioListTile<AttendanceAction>(
                                value: AttendanceAction.timeIn,
                                title: Text('Time In'),
                                subtitle: Text('Records your arrival time.'),
                              ),
                              RadioListTile<AttendanceAction>(
                                value: AttendanceAction.timeOut,
                                title: Text('Time Out'),
                                subtitle: Text('Records your departure time.'),
                              ),
                            ],
                          ),
                        ),

                        const Divider(),
                        CheckboxListTile(
                          value: understood,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              understood = value == true;
                            });
                          },
                          title: const Text(
                            'I understand that the camera will process '
                            'facial data to verify identity and record '
                            'the attendance result.',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(false);
                      },
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      onPressed: understood
                          ? () {
                              _selectedAction = selected;
                              Navigator.of(dialogContext).pop(true);
                            }
                          : null,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Continue'),
                    ),
                  ],
                );
              },
        );
      },
    );

    return accepted == true;
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw StateError('No camera was detected on this device.');
      }

      CameraDescription selectedCamera = cameras.first;

      for (final CameraDescription camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      final CameraController controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}

      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      final CameraController? previous = _cameraController;

      _cameraController = controller;
      await previous?.dispose();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isInitializing = false;
        _statusMessage = _isEmployeeRestricted
            ? 'Only your registered face will be accepted.'
            : 'Position one face inside the guide.';
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _errorMessage = error.description ?? error.code;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final CameraController? controller = _cameraController;

      _cameraController = null;
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed && _selectedAction != null) {
      _initializeCamera();
    }
  }

  Future<void> _scanFace() async {
    final CameraController? controller = _cameraController;

    final AttendanceAction? action = _selectedAction;

    if (_isScanning ||
        action == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isScanning = true;
      _lastMatch = null;
      _statusMessage = 'Scanning and verifying face...';
    });

    try {
      final XFile capturedImage = await controller.takePicture();

      final FaceMatchResult? match = await FaceRecognitionService.recognizeFace(
        imagePath: capturedImage.path,
        expectedEmployeeId: _expectedEmployeeId,
        threshold: _isEmployeeRestricted ? 0.68 : 0.65,
        ambiguityMargin: 0.04,
      );

      if (!mounted) {
        return;
      }

      if (match == null) {
        setState(() {
          _statusMessage = _isEmployeeRestricted
              ? 'Face verification failed. This face does '
                    'not match the signed-in employee.'
              : 'Face not recognized. Look straight, move '
                    'closer, and scan again.';
        });
        return;
      }

      if (_expectedEmployeeId != null &&
          match.employeeId != _expectedEmployeeId) {
        throw const FaceAccountMismatchException();
      }

      final String result = await _recordAttendance(
        match: match,
        action: action,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastMatch = match;
        _statusMessage = result;
      });
    } on FaceAccountMismatchException {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Attendance rejected. The scanned face belongs '
            'to a different employee account.';
      });
    } on ExpectedFaceProfileUnavailableException {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Your account does not have an active registered '
            'face. Contact HR.';
      });
    } on NoActiveFaceProfilesException {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'No active registered face was found. Register '
            'an employee face first.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Face attendance failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<String> _recordAttendance({
    required FaceMatchResult match,
    required AttendanceAction action,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final DateTime now = DateTime.now();

    final DateTime dayStart = AttendancePolicy.dayStart(now);

    final String dateKey = _dateKey(now);

    final DocumentReference<Map<String, dynamic>> employeeReference = firestore
        .collection('employee')
        .doc(match.employeeId);

    final DocumentReference<Map<String, dynamic>> attendanceReference =
        firestore.collection('attendance').doc('${match.employeeId}_$dateKey');

    String resultMessage = '';

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> attendanceSnapshot =
          await transaction.get(attendanceReference);

      final Map<String, dynamic>? existing = attendanceSnapshot.data();

      final DateTime? existingTimeIn = _dateTimeFromValue(existing?['timeIn']);

      final DateTime? existingTimeOut = _dateTimeFromValue(
        existing?['timeOut'],
      );

      if (action == AttendanceAction.timeIn) {
        if (existingTimeIn != null) {
          throw StateError(
            existingTimeOut == null
                ? 'Time in already exists. Choose Time Out instead.'
                : 'Today’s attendance is already completed.',
          );
        }

        final int lateMinutes = AttendancePolicy.lateMinutes(now);

        final String punctuality = AttendancePolicy.punctualityStatus(now);

        transaction.set(attendanceReference, <String, dynamic>{
          'attendanceDate': Timestamp.fromDate(dayStart),
          'employeeId': employeeReference,
          'employeeName': match.fullName,
          'timeIn': Timestamp.fromDate(now),
          'timeOut': null,
          'totalWorkHours': 0.0,
          'lateMinutes': lateMinutes,
          'punctualityStatus': punctuality,
          'undertimeMinutes': 0,
          'overtimeMinutes': 0,
          'overtimeHours': 0.0,
          'status': 'incomplete',
          'verificationMethod': 'face',
          'faceVerified': true,
          'faceMatchScore': _round(match.similarity),
          'faceModelVersion': FaceRecognitionService.modelVersion,
          'recordedAction': 'time_in',
          'scheduleSnapshot': <String, dynamic>{
            'workStart': '07:00',
            'lateAfter': '07:30',
            'overtimeAfter': '17:30',
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final String label = punctuality == 'late'
            ? 'late by $lateMinutes minute'
                  '${lateMinutes == 1 ? '' : 's'}'
            : punctuality == 'early'
            ? 'early'
            : 'on time';

        resultMessage =
            '${match.fullName} timed in successfully — '
            '$label.';

        return;
      }

      if (existingTimeIn == null) {
        throw StateError('No time-in record was found. Choose Time In first.');
      }

      if (existingTimeOut != null) {
        throw StateError('Today’s attendance is already completed.');
      }

      final int totalMinutes = math.max(
        0,
        now.difference(existingTimeIn).inMinutes,
      );

      final double totalHours = AttendancePolicy.hoursFromMinutes(totalMinutes);

      final int overtimeMinutes = AttendancePolicy.overtimeMinutes(now);

      final double overtimeHours = AttendancePolicy.hoursFromMinutes(
        overtimeMinutes,
      );

      final int undertimeMinutes = AttendancePolicy.undertimeMinutes(now);

      transaction.update(attendanceReference, <String, dynamic>{
        'timeOut': Timestamp.fromDate(now),
        'totalWorkHours': _round(totalHours),
        'overtimeMinutes': overtimeMinutes,
        'overtimeHours': _round(overtimeHours),
        'undertimeMinutes': undertimeMinutes,
        'status': 'present',
        'verificationMethod': 'face',
        'faceVerified': true,
        'faceMatchScore': _round(match.similarity),
        'faceModelVersion': FaceRecognitionService.modelVersion,
        'recordedAction': 'time_out',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final String overtimeText = overtimeMinutes > 0
          ? ' Overtime: $overtimeMinutes minute'
                '${overtimeMinutes == 1 ? '' : 's'}.'
          : '';

      resultMessage =
          '${match.fullName} timed out successfully.'
          '$overtimeText';
    });

    return resultMessage;
  }

  String _dateKey(DateTime value) {
    return '${value.year}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _referenceId(dynamic value) {
    if (value is DocumentReference) {
      return value.id;
    }

    final String raw = value?.toString().trim() ?? '';

    if (raw.isEmpty) {
      return '';
    }

    return raw.contains('/') ? raw.split('/').last : raw;
  }

  DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  double _round(double value) {
    return double.parse(value.toStringAsFixed(4));
  }

  String get _actionLabel {
    switch (_selectedAction) {
      case AttendanceAction.timeIn:
        return 'Time In';
      case AttendanceAction.timeOut:
        return 'Time Out';
      case null:
        return 'Attendance';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101828),
      appBar: AppBar(
        title: Text('Face $_actionLabel'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Color(0xFFC62828),
                ),
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF101828), height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final CameraController? controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera is unavailable.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double guideWidth = (constraints.maxWidth * 0.80).clamp(
                230.0,
                370.0,
              );

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _coverPreview(controller),
                  Container(color: Colors.black.withValues(alpha: 0.10)),
                  Center(
                    child: Container(
                      width: guideWidth,
                      height: guideWidth * 1.25,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(guideWidth),
                        border: Border.all(
                          width: 4,
                          color: _isScanning
                              ? const Color(0xFFFFB74D)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isEmployeeRestricted
                            ? 'Restricted to '
                                  '${_expectedEmployeeName ?? 'the signed-in employee'}'
                            : 'HR/Admin shared attendance scanner',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          color: const Color(0xFF101828),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2939),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Selected action: $_actionLabel',
                  style: const TextStyle(
                    color: Color(0xFFB2DDFF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_lastMatch != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _lastMatch!.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Match: '
                  '${(_lastMatch!.similarity * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Color(0xFF98A2B3)),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isScanning ? null : _scanFace,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1565C0),
                  minimumSize: const Size.fromHeight(54),
                ),
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.face_retouching_natural),
                label: Text(
                  _isScanning
                      ? 'Scanning...'
                      : 'Scan Face for '
                            '$_actionLabel',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverPreview(CameraController controller) {
    final Size? previewSize = controller.value.previewSize;

    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
