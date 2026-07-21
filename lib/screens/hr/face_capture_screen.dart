import 'package:flutter/material.dart';

import 'face_capture_mobile.dart'
    if (dart.library.html) 'face_capture_web.dart';

class FaceCaptureScreen extends StatelessWidget {
  const FaceCaptureScreen({
    required this.employeeId,
    required this.fullName,
    super.key,
  });

  final String employeeId;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    return FaceCapturePlatformScreen(
      employeeId: employeeId,
      fullName: fullName,
    );
  }
}