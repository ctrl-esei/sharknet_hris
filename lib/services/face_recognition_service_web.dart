class FaceMatchResult {
  const FaceMatchResult({
    required this.employeeId,
    required this.fullName,
    required this.similarity,
  });

  final String employeeId;
  final String fullName;
  final double similarity;
}

class NoActiveFaceProfilesException implements Exception {
  const NoActiveFaceProfilesException();

  @override
  String toString() =>
      'No active employee has a usable registered face.';
}

class ExpectedFaceProfileUnavailableException implements Exception {
  const ExpectedFaceProfileUnavailableException(this.employeeId);

  final String employeeId;

  @override
  String toString() =>
      'The signed-in employee account does not have an active registered face.';
}

class FaceAccountMismatchException implements Exception {
  const FaceAccountMismatchException();

  @override
  String toString() =>
      'The scanned face does not belong to the signed-in employee account.';
}

class FaceRecognitionService {
  FaceRecognitionService._();

  static const String modelVersion = 'mobilefacenet_192_v1';
  static const int expectedEmbeddingLength = 192;

  static Future<List<double>> createEmbeddingFromPath(
    String imagePath,
  ) {
    throw UnsupportedError(
      'Face embeddings are available only on Android and iOS.',
    );
  }

  static Future<List<double>> createAverageEmbedding(
    List<String> samplePaths,
  ) {
    throw UnsupportedError(
      'Face enrollment is available only on Android and iOS.',
    );
  }

  static Future<void> enrollEmployee({
    required String employeeId,
    required List<String> samplePaths,
    required bool consentAccepted,
  }) {
    throw UnsupportedError(
      'Face enrollment is available only on Android and iOS.',
    );
  }

  static Future<FaceMatchResult?> recognizeFace({
    required String imagePath,
    String? expectedEmployeeId,
    double threshold = 0.65,
    double ambiguityMargin = 0.04,
  }) {
    throw UnsupportedError(
      'Face recognition is available only on Android and iOS.',
    );
  }

  static Future<void> disableEmployeeFace({
    required String employeeId,
  }) {
    throw UnsupportedError(
      'Face management is available only on Android and iOS.',
    );
  }

  static Future<void> dispose() async {}
}
