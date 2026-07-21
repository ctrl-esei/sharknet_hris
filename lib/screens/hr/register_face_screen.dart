import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

class _RegisterFaceScreenState
    extends State<RegisterFaceScreen> {
  bool _consentAccepted = false;

  List<String> _capturedSamplePaths = [];

  bool get _samplesReady =>
      _capturedSamplePaths.length == 5;

  Future<void> _startRegistration() async {
    final List<String>? capturedSamples =
        await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => FaceCaptureScreen(
          employeeId: widget.employeeId,
          fullName: widget.fullName,
        ),
      ),
    );

    if (!mounted ||
        capturedSamples == null ||
        capturedSamples.isEmpty) {
      return;
    }

    setState(() {
      _capturedSamplePaths = capturedSamples;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Five valid face samples were captured.',
        ),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeeReference = FirebaseFirestore.instance
        .collection('employee')
        .doc(widget.employeeId);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Register Employee Face'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: employeeReference.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load employee: ${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Employee record was not found.',
              ),
            );
          }

          final Map<String, dynamic> data =
              snapshot.data!.data() ?? {};

          final bool faceRegistered =
              data['faceRegistered'] == true;

          final String biometricStatus =
              data['biometricStatus']?.toString() ??
                  'not_enrolled';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildEmployeeCard(
                faceRegistered: faceRegistered,
                biometricStatus: biometricStatus,
              ),
              const SizedBox(height: 20),
              const Text(
                'Registration Requirements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const _RequirementItem(
                icon: Icons.light_mode_outlined,
                text: 'Use a bright, evenly lit area.',
              ),
              const _RequirementItem(
                icon: Icons.person_outline,
                text:
                    'Only the selected employee may appear.',
              ),
              const _RequirementItem(
                icon: Icons.remove_red_eye_outlined,
                text:
                    'Remove masks, sunglasses, and coverings.',
              ),
              const _RequirementItem(
                icon: Icons.threesixty,
                text:
                    'Follow all head movement instructions.',
              ),
              const _RequirementItem(
                icon: Icons.sentiment_satisfied_alt,
                text:
                    'Complete the blink and smile checks.',
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _consentAccepted,
                contentPadding: EdgeInsets.zero,
                controlAffinity:
                    ListTileControlAffinity.leading,
                title: const Text(
                  'The employee gives permission to '
                  'register and use their face template '
                  'for attendance verification.',
                ),
                onChanged: (value) {
                  setState(() {
                    _consentAccepted = value == true;
                  });
                },
              ),
              if (_samplesReady) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: const Color(0xFFA5D6A7),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Five valid samples are ready. '
                          'The employee is not yet marked as '
                          'registered until the face embedding '
                          'is generated and saved.',
                          style: TextStyle(
                            color: Color(0xFF1B5E20),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _consentAccepted
                    ? _startRegistration
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(
                  Icons.camera_alt_outlined,
                ),
                label: Text(
                  _samplesReady
                      ? 'Recapture Face Samples'
                      : faceRegistered
                          ? 'Update Registered Face'
                          : 'Start Face Registration',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmployeeCard({
    required bool faceRegistered,
    required String biometricStatus,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFFE3F2FD),
            child: Icon(
              Icons.face_outlined,
              size: 42,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.employeeId.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: faceRegistered
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              faceRegistered
                  ? 'Face Registered – '
                      '${_formatLabel(biometricStatus)}'
                  : 'Face Not Enrolled',
              style: TextStyle(
                color: faceRegistered
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFEF6C00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}'
              '${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _RequirementItem extends StatelessWidget {
  const _RequirementItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}