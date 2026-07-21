import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FaceAttendanceScreen extends StatefulWidget {
  const FaceAttendanceScreen({super.key});

  @override
  State<FaceAttendanceScreen> createState() =>
      _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState
    extends State<FaceAttendanceScreen> {
  final TextEditingController _employeeIdController =
      TextEditingController();

  bool _isChecking = false;

  @override
  void dispose() {
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _continueToCamera() async {
    FocusScope.of(context).unfocus();

    final employeeId =
        _employeeIdController.text.trim().toLowerCase();

    if (employeeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an employee ID.'),
        ),
      );

      return;
    }

    setState(() {
      _isChecking = true;
    });

    try {
      final employeeDocument = await FirebaseFirestore.instance
          .collection('employee')
          .doc(employeeId)
          .get();

      if (!mounted) {
        return;
      }

      if (!employeeDocument.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee was not found.'),
          ),
        );

        return;
      }

      final data = employeeDocument.data() ?? {};

      final fullName =
          data['fullName']?.toString() ?? employeeId;

      final faceRegistered =
          data['faceRegistered'] == true;

      final biometricStatus =
          data['biometricStatus']?.toString() ??
              'not_enrolled';

      if (!faceRegistered ||
          biometricStatus != 'active') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$fullName does not have an active '
              'registered face.',
            ),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$fullName is ready for face verification. '
            'The live camera will be connected next.',
          ),
          backgroundColor: const Color(0xFF1565C0),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to check employee.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Face Attendance'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 15),
            const Icon(
              Icons.face_retouching_natural,
              size: 90,
              color: Color(0xFF1565C0),
            ),
            const SizedBox(height: 17),
            const Text(
              'Employee Face Verification',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the employee ID before scanning the face. '
              'This uses one-to-one verification for better '
              'accuracy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _employeeIdController,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                labelText: 'Employee ID',
                hintText: 'Example: emp001',
                prefixIcon:
                    const Icon(Icons.badge_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onSubmitted: (_) => _continueToCamera(),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed:
                  _isChecking ? null : _continueToCamera,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _isChecking
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(
                _isChecking
                    ? 'Checking Employee...'
                    : 'Continue to Face Scan',
              ),
            ),
          ],
        ),
      ),
    );
  }
}