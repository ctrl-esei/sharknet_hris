
import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  static const List<String> _instructions = <String>[
    'Look straight at the camera with both eyes open.',
    'Turn your head slightly to one side.',
    'Turn your head slightly to the opposite side.',
    'Look straight and blink both eyes.',
    'Look straight and smile naturally.',
  ];

  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  final List<String> _samplePaths = <String>[];

  bool _isInitializing = true;
  bool _isProcessing = false;

  String? _errorMessage;
  double? _firstSideYaw;

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  int get _sampleIndex => _samplePaths.length;

  bool get _isComplete =>
      _samplePaths.length >= _requiredSampleCount;

  String get _instruction => _isComplete
      ? 'Face samples captured successfully.'
      : _instructions[_sampleIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!_isSupportedPlatform) {
      _isInitializing = false;
      _errorMessage =
          'Face capture is available only on Android and iOS.';
      return;
    }

    _initialize();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      _faceDetector ??= await FaceDetector.create(
        model: FaceDetectionModel.frontCamera,
        minScore: 0.80,
        minFaceSize: 0.20,
      );

      final List<CameraDescription> cameras =
          await availableCameras();

      if (cameras.isEmpty) {
        throw StateError(
          'No camera was detected on this device.',
        );
      }

      CameraDescription selectedCamera = cameras.first;

      for (final CameraDescription camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      final CameraController controller =
          await _createCameraController(selectedCamera);

      final CameraController? previousController =
          _cameraController;

      _cameraController = controller;
      await previousController?.dispose();

      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}

      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isInitializing = false;
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

  Future<CameraController> _createCameraController(
    CameraDescription camera,
  ) async {
    final List<ResolutionPreset> presets = <ResolutionPreset>[
      ResolutionPreset.veryHigh,
      ResolutionPreset.high,
      ResolutionPreset.medium,
    ];

    Object? lastError;

    for (final ResolutionPreset preset in presets) {
      final CameraController controller = CameraController(
        camera,
        preset,
        enableAudio: false,
      );

      try {
        await controller.initialize();
        return controller;
      } catch (error) {
        lastError = error;
        await controller.dispose();
      }
    }

    throw StateError(
      'Unable to initialize the front camera: $lastError',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isSupportedPlatform) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initialize();
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
        _isComplete ||
        controller == null ||
        detector == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile capturedImage = await controller.takePicture();
      final Uint8List bytes = await capturedImage.readAsBytes();

      final List<Face> faces = await detector.detectFacesFromBytes(
        bytes,
        mode: FaceDetectionMode.full,
      );

      final _ValidationResult validation = _validateFace(
        faces: faces,
        sampleIndex: _sampleIndex,
      );

      if (!validation.valid) {
        _showMessage(validation.message, error: true);
        return;
      }

      final Face face = faces.first;

      if (_sampleIndex == 1) {
        _firstSideYaw = face.headEulerAngleY;
      }

      setState(() {
        _samplePaths.add(capturedImage.path);
      });

      _showMessage(
        'Sample ${_samplePaths.length} of '
        '$_requiredSampleCount accepted.',
        error: false,
      );

      if (_isComplete) {
        await Future<void>.delayed(
          const Duration(milliseconds: 650),
        );

        if (!mounted) {
          return;
        }

        Navigator.of(context).pop<List<String>>(
          List<String>.unmodifiable(_samplePaths),
        );
      }
    } on CameraException catch (error) {
      _showMessage(_cameraErrorMessage(error), error: true);
    } catch (error) {
      _showMessage(
        'Unable to capture the face sample: $error',
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

  _ValidationResult _validateFace({
    required List<Face> faces,
    required int sampleIndex,
  }) {
    if (faces.isEmpty) {
      return const _ValidationResult.invalid(
        'No face was detected. Move closer and use better lighting.',
      );
    }

    if (faces.length > 1) {
      return const _ValidationResult.invalid(
        'More than one face was detected.',
      );
    }

    final Face face = faces.first;

    if (face.score < 0.80) {
      return const _ValidationResult.invalid(
        'The face is not clear enough. Clean the lens and use better lighting.',
      );
    }

    if (face.widthFraction < 0.25) {
      return const _ValidationResult.invalid(
        'Move closer to the camera.',
      );
    }

    final double yaw = face.headEulerAngleY ?? 0;
    final double pitch = face.headEulerAngleX ?? 0;
    final double roll = face.headEulerAngleZ ?? 0;

    if (pitch.abs() > 25) {
      return const _ValidationResult.invalid(
        'Keep your face level.',
      );
    }

    if (roll.abs() > 20) {
      return const _ValidationResult.invalid(
        'Keep your head upright.',
      );
    }

    switch (sampleIndex) {
      case 0:
        if (yaw.abs() > 12) {
          return const _ValidationResult.invalid(
            'Look directly at the camera.',
          );
        }

        if (!_eyesOpen(face)) {
          return const _ValidationResult.invalid(
            'Keep both eyes open.',
          );
        }
        break;

      case 1:
        if (yaw.abs() < 8 || yaw.abs() > 32) {
          return const _ValidationResult.invalid(
            'Turn your head slightly to one side.',
          );
        }
        break;

      case 2:
        if (yaw.abs() < 8 || yaw.abs() > 32) {
          return const _ValidationResult.invalid(
            'Turn your head slightly to the opposite side.',
          );
        }

        final double? firstSideYaw = _firstSideYaw;
        if (firstSideYaw != null && yaw.sign == firstSideYaw.sign) {
          return const _ValidationResult.invalid(
            'Turn toward the opposite side from the previous sample.',
          );
        }
        break;

      case 3:
        if (yaw.abs() > 15) {
          return const _ValidationResult.invalid(
            'Look straight before blinking.',
          );
        }

        if (!_eyesClosed(face)) {
          return const _ValidationResult.invalid(
            'Close both eyes briefly while capturing.',
          );
        }
        break;

      case 4:
        if (yaw.abs() > 15) {
          return const _ValidationResult.invalid(
            'Look straight while smiling.',
          );
        }

        if ((face.smilingProbability ?? 0) < 0.45) {
          return const _ValidationResult.invalid(
            'Smile naturally and try again.',
          );
        }

        if (!_eyesOpen(face)) {
          return const _ValidationResult.invalid(
            'Keep both eyes open while smiling.',
          );
        }
        break;
    }

    return const _ValidationResult.valid();
  }

  bool _eyesOpen(Face face) {
    final double? left = face.leftEyeOpenProbability;
    final double? right = face.rightEyeOpenProbability;

    return left != null &&
        right != null &&
        left >= 0.45 &&
        right >= 0.45;
  }

  bool _eyesClosed(Face face) {
    final double? left = face.leftEyeOpenProbability;
    final double? right = face.rightEyeOpenProbability;

    return left != null &&
        right != null &&
        left <= 0.40 &&
        right <= 0.40;
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
              ? const Color(0xFFC62828)
              : const Color(0xFF2E7D32),
        ),
      );
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'Camera permission was denied. Allow camera access in Settings.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera access is disabled. Enable it in Settings.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';
      default:
        return error.description ?? 'Unable to open the camera.';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceDetector?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101828),
      appBar: AppBar(
        title: const Text('Capture Face Samples'),
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
        child: SingleChildScrollView(
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
                  Icons.camera_alt_outlined,
                  size: 58,
                  color: Color(0xFFC62828),
                ),
                const SizedBox(height: 14),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _initialize,
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
            builder: (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              final double guideWidth =
                  (constraints.maxWidth * 0.82).clamp(240.0, 380.0);

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _buildCoverPreview(controller),
                  Container(
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                  Center(
                    child: Container(
                      width: guideWidth,
                      height: guideWidth * 1.25,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(guideWidth),
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
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _employeeBanner(),
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 17, 22, 22),
          color: const Color(0xFF101828),
          child: Column(
            children: <Widget>[
              _progress(),
              const SizedBox(height: 13),
              Text(
                _instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 76,
                height: 76,
                child: FilledButton(
                  onPressed: _isProcessing ? null : _captureSample,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1565C0),
                    padding: EdgeInsets.zero,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 27,
                          height: 27,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Icon(Icons.camera_alt, size: 34),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPreview(CameraController controller) {
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

  Widget _employeeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.face_outlined, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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

  Widget _progress() {
    return Row(
      children: List<Widget>.generate(
        _requiredSampleCount,
        (int index) {
          final bool completed = index < _samplePaths.length;
          final bool current = index == _samplePaths.length;

          return Expanded(
            child: Container(
              height: 7,
              margin: EdgeInsets.only(
                right: index == _requiredSampleCount - 1 ? 0 : 7,
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

class _ValidationResult {
  const _ValidationResult.valid()
      : valid = true,
        message = '';

  const _ValidationResult.invalid(this.message) : valid = false;

  final bool valid;
  final String message;
}
