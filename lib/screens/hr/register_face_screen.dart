import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/face_recognition_service.dart';
import 'face_capture_screen.dart';

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({
    required this.employeeId,
    required this.fullName,
    super.key,
  });

  final String employeeId;
  final String fullName;

  @override
  State<RegisterFaceScreen> createState() =>
      _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  bool _consentAccepted = false;
  bool _isProcessing = false;

  Future<void> _startEnrollment() async {
    if (!_consentAccepted) {
      _showMessage(
        'Accept the biometric consent before registering the face.',
        error: true,
      );
      return;
    }

    final List<String>? samplePaths =
        await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => FaceCapturePlatformScreen(
          employeeId: widget.employeeId,
          fullName: widget.fullName,
        ),
      ),
    );

    if (!mounted || samplePaths == null || samplePaths.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await FaceRecognitionService.enrollEmployee(
        employeeId: widget.employeeId,
        samplePaths: samplePaths,
        consentAccepted: _consentAccepted,
      );

      _showMessage(
        'Face registered successfully. The employee is now active for face attendance.',
        error: false,
      );
    } catch (error) {
      _showMessage(
        'Face registration failed: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool error}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? const Color(0xFFD92D20)
              : const Color(0xFF039855),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> employeeReference =
        FirebaseFirestore.instance
            .collection('employee')
            .doc(widget.employeeId);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Register Face'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: employeeReference.snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
        ) {
          final Map<String, dynamic> data =
              snapshot.data?.data() ?? <String, dynamic>{};

          final bool faceRegistered = data['faceRegistered'] == true;
          final bool faceActive =
              faceRegistered && data['faceActive'] != false;

          final List<dynamic> embedding = data['faceEmbedding'] is List
              ? data['faceEmbedding'] as List<dynamic>
              : <dynamic>[];

          final String modelVersion =
              data['faceModelVersion']?.toString().trim() ?? '';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 29,
                      backgroundColor: const Color(0xFFEAF2FF),
                      child: Text(
                        _initials(widget.fullName),
                        style: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.fullName,
                            style: const TextStyle(
                              color: Color(0xFF101828),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.employeeId.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: faceActive
                      ? const Color(0xFFECFDF3)
                      : const Color(0xFFFFFAEB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: faceActive
                        ? const Color(0xFFA6F4C5)
                        : const Color(0xFFFEC84B),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    _statusRow(
                      label: 'Biometric Status',
                      value: data['biometricStatus']?.toString() ??
                          'not_enrolled',
                    ),
                    _statusRow(
                      label: 'Face Registered',
                      value: faceRegistered ? 'Yes' : 'No',
                    ),
                    _statusRow(
                      label: 'Face Active',
                      value: faceActive ? 'Yes' : 'No',
                    ),
                    _statusRow(
                      label: 'Embedding Values',
                      value: embedding.length.toString(),
                    ),
                    _statusRow(
                      label: 'Model Version',
                      value: modelVersion.isEmpty ? 'Not set' : modelVersion,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consentAccepted,
                  onChanged: _isProcessing
                      ? null
                      : (bool? value) {
                          setState(() {
                            _consentAccepted = value ?? false;
                          });
                        },
                  title: const Text(
                    'Biometric consent',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'The employee agrees that a numerical face template '
                    'will be processed for attendance verification.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isProcessing ? null : _startEnrollment,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.face_retouching_natural),
                label: Text(
                  _isProcessing
                      ? 'Generating face template...'
                      : faceRegistered
                          ? 'Update Registered Face'
                          : 'Register Face',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Successful registration stores a 192-value face embedding. '
                'Raw captured photos are not written to Firestore.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF475467),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String fullName) {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
