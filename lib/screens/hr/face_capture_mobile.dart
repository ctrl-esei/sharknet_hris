import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as image_library;

class FaceCapturePlatformScreen extends StatefulWidget {
  const FaceCapturePlatformScreen({
    required this.employeeId,
    required this.fullName,
    super.key,
  });

  final String employeeId;
  final String fullName;

  @override
  State<FaceCapturePlatformScreen> createState() =>
      _FaceCapturePlatformScreenState();
}

class _FaceCapturePlatformScreenState
    extends State<FaceCapturePlatformScreen>
    with WidgetsBindingObserver {
  static const int _requiredSampleCount = 5;

  static const List<String> _sampleInstructions = [
    'Look straight at the camera with both eyes open.',
    'Turn your head slightly to either side.',
    'Turn your head slightly to the opposite side.',
    'Look straight and blink both eyes.',
    'Look straight and smile naturally.',
  ];

  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  final List<String> _capturedSamplePaths = [];

  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isSupportedPlatform = true;

  String? _errorMessage;
  double? _firstSideYaw;

  int get _currentSampleIndex => _capturedSamplePaths.length;

  bool get _captureComplete =>
      _capturedSamplePaths.length >= _requiredSampleCount;

  String get _currentInstruction {
    if (_captureComplete) {
      return 'Face samples captured successfully.';
    }

    return _sampleInstructions[_currentSampleIndex];
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final bool isAndroid =
        defaultTargetPlatform == TargetPlatform.android;

    final bool isIos =
        defaultTargetPlatform == TargetPlatform.iOS;

    _isSupportedPlatform = isAndroid || isIos;

    if (!_isSupportedPlatform) {
      _isInitializing = false;
      _errorMessage =
          'Face detection is available only on Android and iOS.';
      return;
    }

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true,
        enableLandmarks: true,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.20,
      ),
    );

    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    final CameraController? controller = _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed &&
        _isSupportedPlatform) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!_isSupportedPlatform) {
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      final List<CameraDescription> cameras =
          await availableCameras();

      if (cameras.isEmpty) {
        throw StateError(
          'No camera was detected on this device.',
        );
      }

      CameraDescription selectedCamera = cameras.first;

      for (final CameraDescription camera in cameras) {
        if (camera.lensDirection ==
            CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      await _cameraController?.dispose();

      final CameraController controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _cameraController = controller;

      await controller.initialize();

      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Some front cameras do not support flash settings.
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isInitializing = false;
        _errorMessage = null;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _errorMessage = _cameraErrorMessage(error);
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

  Future<void> _disposeCamera() async {
    final CameraController? controller = _cameraController;

    _cameraController = null;

    await controller?.dispose();
  }

  Future<void> _captureSample() async {
    final CameraController? controller = _cameraController;
    final FaceDetector? detector = _faceDetector;

    if (_isProcessing ||
        _captureComplete ||
        controller == null ||
        detector == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile capturedImage =
          await controller.takePicture();

      final InputImage inputImage =
          InputImage.fromFilePath(capturedImage.path);

      final List<Face> detectedFaces =
          await detector.processImage(inputImage);

      final Uint8List imageBytes =
          await capturedImage.readAsBytes();

      final image_library.Image? decodedImage =
          image_library.decodeImage(imageBytes);

      if (decodedImage == null) {
        _showError(
          'The captured image could not be processed. '
          'Please try again.',
        );
        return;
      }

      final _FaceValidationResult validation =
          _validateFace(
        faces: detectedFaces,
        imageWidth: decodedImage.width,
        imageHeight: decodedImage.height,
        sampleIndex: _currentSampleIndex,
      );

      if (!validation.isValid) {
        _showError(validation.message);
        return;
      }

      final Face validFace = detectedFaces.first;

      if (_currentSampleIndex == 1) {
        _firstSideYaw = validFace.headEulerAngleY;
      }

      setState(() {
        _capturedSamplePaths.add(capturedImage.path);
      });

      _showSuccess(
        'Sample ${_capturedSamplePaths.length} of '
        '$_requiredSampleCount accepted.',
      );

      if (_captureComplete) {
        await Future<void>.delayed(
          const Duration(milliseconds: 700),
        );

        if (!mounted) {
          return;
        }

        Navigator.of(context).pop<List<String>>(
          List<String>.unmodifiable(
            _capturedSamplePaths,
          ),
        );
      }
    } on CameraException catch (error) {
      _showError(_cameraErrorMessage(error));
    } catch (error) {
      _showError(
        'Unable to process the face sample: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  _FaceValidationResult _validateFace({
    required List<Face> faces,
    required int imageWidth,
    required int imageHeight,
    required int sampleIndex,
  }) {
    if (faces.isEmpty) {
      return const _FaceValidationResult.invalid(
        'No face was detected. Move closer and try again.',
      );
    }

    if (faces.length > 1) {
      return const _FaceValidationResult.invalid(
        'More than one face was detected. '
        'Only the selected employee may appear on camera.',
      );
    }

    final Face face = faces.first;

    final double shortImageSide = math.min(
      imageWidth.toDouble(),
      imageHeight.toDouble(),
    );

    final double faceWidthRatio =
        face.boundingBox.width / shortImageSide;

    if (faceWidthRatio < 0.23) {
      return const _FaceValidationResult.invalid(
        'Move closer to the camera. Your face is too small.',
      );
    }

    final double yaw = face.headEulerAngleY ?? 0;
    final double pitch = face.headEulerAngleX ?? 0;
    final double roll = face.headEulerAngleZ ?? 0;

    if (pitch.abs() > 25) {
      return const _FaceValidationResult.invalid(
        'Keep your face level. Do not look too far up or down.',
      );
    }

    if (roll.abs() > 20) {
      return const _FaceValidationResult.invalid(
        'Keep your head upright.',
      );
    }

    switch (sampleIndex) {
      case 0:
        if (yaw.abs() > 12) {
          return const _FaceValidationResult.invalid(
            'For the first sample, look directly at the camera.',
          );
        }

        if (!_eyesAreOpen(face)) {
          return const _FaceValidationResult.invalid(
            'Keep both eyes open for the first sample.',
          );
        }

        break;

      case 1:
        if (yaw.abs() < 8 || yaw.abs() > 32) {
          return const _FaceValidationResult.invalid(
            'Turn your head slightly to one side. '
            'Do not turn too far.',
          );
        }

        break;

      case 2:
        if (yaw.abs() < 8 || yaw.abs() > 32) {
          return const _FaceValidationResult.invalid(
            'Turn your head slightly to the opposite side.',
          );
        }

        final double? firstYaw = _firstSideYaw;

        if (firstYaw != null &&
            yaw.sign == firstYaw.sign) {
          return const _FaceValidationResult.invalid(
            'Turn toward the opposite side from the previous sample.',
          );
        }

        break;

      case 3:
        if (yaw.abs() > 15) {
          return const _FaceValidationResult.invalid(
            'Look straight at the camera before blinking.',
          );
        }

        if (!_eyesAreClosed(face)) {
          return const _FaceValidationResult.invalid(
            'Blink both eyes while capturing this sample.',
          );
        }

        break;

      case 4:
        if (yaw.abs() > 15) {
          return const _FaceValidationResult.invalid(
            'Look straight at the camera while smiling.',
          );
        }

        final double? smileProbability =
            face.smilingProbability;

        if (smileProbability == null ||
            smileProbability < 0.55) {
          return const _FaceValidationResult.invalid(
            'Smile naturally and capture the sample again.',
          );
        }

        if (!_eyesAreOpen(face)) {
          return const _FaceValidationResult.invalid(
            'Keep both eyes open while smiling.',
          );
        }

        break;
    }

    return const _FaceValidationResult.valid();
  }

  bool _eyesAreOpen(Face face) {
    final double? leftEye =
        face.leftEyeOpenProbability;

    final double? rightEye =
        face.rightEyeOpenProbability;

    if (leftEye == null || rightEye == null) {
      return false;
    }

    return leftEye >= 0.45 &&
        rightEye >= 0.45;
  }

  bool _eyesAreClosed(Face face) {
    final double? leftEye =
        face.leftEyeOpenProbability;

    final double? rightEye =
        face.rightEyeOpenProbability;

    if (leftEye == null || rightEye == null) {
      return false;
    }

    return leftEye <= 0.40 &&
        rightEye <= 0.40;
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'Camera permission was denied. '
            'Allow camera access in the device settings.';

      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera access is disabled. '
            'Enable it from the device settings.';

      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';

      case 'AudioAccessDenied':
        return 'Microphone permission was denied.';

      default:
        return error.description ??
            'Unable to open the camera.';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _cameraController?.dispose();
    _faceDetector?.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupportedPlatform) {
      return _buildUnsupportedScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101828),
      appBar: AppBar(
        title: const Text('Capture Face Samples'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildUnsupportedScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Face Samples'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage ??
                'This platform is not supported.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 60,
                  color: Color(0xFFC62828),
                ),
                const SizedBox(height: 15),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final CameraController? controller = _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera is unavailable.',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: 0.15,
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 240,
                  height: 310,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(150),
                    border: Border.all(
                      color: _isProcessing
                          ? const Color(0xFFFFB74D)
                          : Colors.white,
                      width: 4,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                right: 18,
                child: _buildEmployeeBanner(),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            22,
            18,
            22,
            22,
          ),
          color: const Color(0xFF101828),
          child: Column(
            children: [
              _buildProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                _currentInstruction,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 76,
                height: 76,
                child: FilledButton(
                  onPressed:
                      _isProcessing ? null : _captureSample,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.white,
                    foregroundColor:
                        const Color(0xFF1565C0),
                    padding: EdgeInsets.zero,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 34,
                        ),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Tap the camera button when ready',
                style: TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.face_outlined,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.employeeId.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFD0D5DD),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(
        _requiredSampleCount,
        (index) {
          final bool completed =
              index < _capturedSamplePaths.length;

          final bool current =
              index == _capturedSamplePaths.length;

          return Expanded(
            child: Container(
              height: 7,
              margin: EdgeInsets.only(
                right:
                    index == _requiredSampleCount - 1
                        ? 0
                        : 7,
              ),
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFF4CAF50)
                    : current
                        ? const Color(0xFFFFB74D)
                        : const Color(0xFF344054),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FaceValidationResult {
  const _FaceValidationResult.valid()
      : isValid = true,
        message = '';

  const _FaceValidationResult.invalid(
    this.message,
  ) : isValid = false;

  final bool isValid;
  final String message;
}