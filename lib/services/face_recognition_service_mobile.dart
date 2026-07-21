import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';

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

  static FaceDetector? _detector;
  static Future<FaceDetector>? _detectorFuture;

  static Future<FaceDetector> _getDetector() async {
    if (_detector != null) {
      return _detector!;
    }

    if (_detectorFuture != null) {
      return _detectorFuture!;
    }

    final Future<FaceDetector> creation = FaceDetector.create(
      model: FaceDetectionModel.frontCamera,
      minScore: 0.80,
      minFaceSize: 0.18,
    );

    _detectorFuture = creation;

    try {
      final FaceDetector detector = await creation;
      _detector = detector;
      return detector;
    } finally {
      _detectorFuture = null;
    }
  }

  static Future<List<double>> createEmbeddingFromPath(
    String imagePath,
  ) async {
    final Uint8List bytes = await File(imagePath).readAsBytes();
    final FaceDetector detector = await _getDetector();

    final List<Face> faces = await detector.detectFacesFromBytes(
      bytes,
      mode: FaceDetectionMode.full,
    );

    if (faces.isEmpty) {
      throw StateError('No face was detected in the captured image.');
    }

    if (faces.length > 1) {
      throw StateError(
        'More than one face was detected. Only one employee may appear.',
      );
    }

    final Face face = faces.first;

    if (face.score < 0.80 || face.widthFraction < 0.18) {
      throw StateError(
        'The face is too small or unclear. Move closer and use better lighting.',
      );
    }

    final List<double> embedding = List<double>.from(
      await detector.getFaceEmbedding(face, bytes),
    );

    if (embedding.length != expectedEmbeddingLength) {
      throw StateError(
        'Unexpected embedding size ${embedding.length}; '
        'expected $expectedEmbeddingLength.',
      );
    }

    return _normalize(embedding);
  }

  static Future<List<double>> createAverageEmbedding(
    List<String> samplePaths,
  ) async {
    if (samplePaths.length < 3) {
      throw StateError(
        'At least three accepted face samples are required.',
      );
    }

    final List<List<double>> embeddings = <List<double>>[];

    for (final String path in samplePaths) {
      embeddings.add(await createEmbeddingFromPath(path));
    }

    final List<double> average = List<double>.filled(
      expectedEmbeddingLength,
      0,
    );

    for (final List<double> embedding in embeddings) {
      for (int index = 0; index < expectedEmbeddingLength; index++) {
        average[index] += embedding[index];
      }
    }

    for (int index = 0; index < expectedEmbeddingLength; index++) {
      average[index] /= embeddings.length;
    }

    return _normalize(average);
  }

  static Future<void> enrollEmployee({
    required String employeeId,
    required List<String> samplePaths,
    required bool consentAccepted,
  }) async {
    if (!consentAccepted) {
      throw StateError(
        'Biometric consent must be accepted before enrollment.',
      );
    }

    final DocumentReference<Map<String, dynamic>> employeeReference =
        FirebaseFirestore.instance.collection('employee').doc(employeeId);

    final DocumentSnapshot<Map<String, dynamic>> employeeSnapshot =
        await employeeReference.get();

    if (!employeeSnapshot.exists) {
      throw StateError('Employee record was not found.');
    }

    final String employmentStatus = employeeSnapshot
            .data()?['employmentStatus']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'active';

    if (employmentStatus != 'active') {
      throw StateError('Only active employees can register a face.');
    }

    final List<double> embedding =
        await createAverageEmbedding(samplePaths);

    await employeeReference.set(
      <String, dynamic>{
        'biometricStatus': 'enrolled',
        'consentAccepted': true,
        'faceActive': true,
        'faceRegistered': true,
        'faceEmbedding': embedding,
        'faceEmbeddingDimensions': embedding.length,
        'faceSampleCount': samplePaths.length,
        'faceModelVersion': modelVersion,
        'faceEnrolledAt': FieldValue.serverTimestamp(),
        'faceUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<FaceMatchResult?> recognizeFace({
    required String imagePath,
    String? expectedEmployeeId,
    double threshold = 0.65,
    double ambiguityMargin = 0.04,
  }) async {
    final List<double> capturedEmbedding =
        await createEmbeddingFromPath(imagePath);

    final QuerySnapshot<Map<String, dynamic>> employeeSnapshot =
        await FirebaseFirestore.instance.collection('employee').get();

    final List<_StoredProfile> profiles = <_StoredProfile>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in employeeSnapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final String employmentStatus = data['employmentStatus']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'active';

      final bool registered = data['faceRegistered'] == true;
      final bool active = data['faceActive'] != false;
      final List<double> embedding = _readEmbedding(data['faceEmbedding']);

      if (employmentStatus != 'active' ||
          !registered ||
          !active ||
          embedding.length != expectedEmbeddingLength) {
        continue;
      }

      profiles.add(
        _StoredProfile(
          employeeId: document.id,
          fullName: data['fullName']?.toString().trim().isNotEmpty == true
              ? data['fullName'].toString().trim()
              : document.id.toUpperCase(),
          embedding: _normalize(embedding),
        ),
      );
    }

    if (profiles.isEmpty) {
      throw const NoActiveFaceProfilesException();
    }

    final String expectedId =
        expectedEmployeeId?.trim().toLowerCase() ?? '';

    if (expectedId.isNotEmpty &&
        !profiles.any(
          (_StoredProfile profile) =>
              profile.employeeId.trim().toLowerCase() == expectedId,
        )) {
      throw ExpectedFaceProfileUnavailableException(
        expectedEmployeeId!,
      );
    }

    _StoredProfile? bestProfile;
    double bestSimilarity = -1;
    double secondBestSimilarity = -1;

    for (final _StoredProfile profile in profiles) {
      final double similarity = _cosineSimilarity(
        capturedEmbedding,
        profile.embedding,
      );

      if (similarity > bestSimilarity) {
        secondBestSimilarity = bestSimilarity;
        bestSimilarity = similarity;
        bestProfile = profile;
      } else if (similarity > secondBestSimilarity) {
        secondBestSimilarity = similarity;
      }
    }

    if (bestProfile == null || bestSimilarity < threshold) {
      return null;
    }

    if (secondBestSimilarity >= 0 &&
        bestSimilarity - secondBestSimilarity < ambiguityMargin) {
      throw StateError(
        'The face match is ambiguous. Move closer and scan again.',
      );
    }

    if (expectedId.isNotEmpty &&
        bestProfile.employeeId.trim().toLowerCase() != expectedId) {
      throw const FaceAccountMismatchException();
    }

    return FaceMatchResult(
      employeeId: bestProfile.employeeId,
      fullName: bestProfile.fullName,
      similarity: bestSimilarity,
    );
  }

  static Future<void> disableEmployeeFace({
    required String employeeId,
  }) async {
    await FirebaseFirestore.instance
        .collection('employee')
        .doc(employeeId)
        .set(
      <String, dynamic>{
        'biometricStatus': 'disabled',
        'faceActive': false,
        'faceRegistered': false,
        'faceUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> dispose() async {
    final FaceDetector? detector = _detector;

    _detector = null;
    _detectorFuture = null;

    if (detector != null) {
      await detector.dispose();
    }
  }

  static List<double> _readEmbedding(dynamic value) {
    if (value is! Iterable) {
      return <double>[];
    }

    try {
      return value
          .map<double>((dynamic item) => (item as num).toDouble())
          .toList(growable: false);
    } catch (_) {
      return <double>[];
    }
  }

  static double _cosineSimilarity(
    List<double> first,
    List<double> second,
  ) {
    if (first.length != second.length || first.isEmpty) {
      return -1;
    }

    double dot = 0;
    double firstMagnitude = 0;
    double secondMagnitude = 0;

    for (int index = 0; index < first.length; index++) {
      dot += first[index] * second[index];
      firstMagnitude += first[index] * first[index];
      secondMagnitude += second[index] * second[index];
    }

    if (firstMagnitude == 0 || secondMagnitude == 0) {
      return -1;
    }

    return dot /
        (math.sqrt(firstMagnitude) * math.sqrt(secondMagnitude));
  }

  static List<double> _normalize(List<double> vector) {
    double sumOfSquares = 0;

    for (final double value in vector) {
      sumOfSquares += value * value;
    }

    final double magnitude = math.sqrt(sumOfSquares);

    if (magnitude == 0) {
      throw StateError('The generated face embedding is empty.');
    }

    return vector
        .map<double>((double value) => value / magnitude)
        .toList(growable: false);
  }
}

class _StoredProfile {
  const _StoredProfile({
    required this.employeeId,
    required this.fullName,
    required this.embedding,
  });

  final String employeeId;
  final String fullName;
  final List<double> embedding;
}
