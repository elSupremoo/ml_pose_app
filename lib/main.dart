import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'dart:math' as math;

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: FutureBuilder(
          future: Permission.camera.request(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return LiveCameraView();
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}

class LiveCameraView extends StatefulWidget {
  @override
  _LiveCameraViewState createState() => _LiveCameraViewState();
}

class _LiveCameraViewState extends State<LiveCameraView> {
  late CameraController _controller;
  late PoseDetector _poseDetector;
  bool _isDetecting = false;
  List<Pose> _poses = [];
  Timer? _iosTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final backCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(backCamera, ResolutionPreset.medium);
    await _controller.initialize();
    await _controller.setFlashMode(FlashMode.off);

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    if (Platform.isIOS) {
      _iosTimer = Timer.periodic(Duration(milliseconds: 20), (timer) async {
        if (!_controller.value.isInitialized || _isDetecting) return;
        _isDetecting = true;

        try {
          final file = await _controller.takePicture();
          final inputImage = InputImage.fromFilePath(file.path);
          final poses = await _poseDetector.processImage(inputImage);
          setState(() => _poses = poses);
          await File(file.path).delete();
        } catch (e) {
          debugPrint("iOS Pose detection error: $e");
        }

        _isDetecting = false;
      });
    } else {
      _controller.startImageStream((CameraImage image) async {
        if (_isDetecting) return;
        _isDetecting = true;

        final inputImage = _cameraImageToInputImage(
          image,
          _controller.description,
        );
        if (inputImage == null) {
          _isDetecting = false;
          return;
        }

        try {
          final poses = await _poseDetector.processImage(inputImage);
          setState(() => _poses = poses);
        } catch (e) {
          debugPrint("Android Pose detection error: $e");
        }

        _isDetecting = false;
      });
    }

    setState(() {});
  }

  InputImage? _cameraImageToInputImage(
    CameraImage image,
    CameraDescription description,
  ) {
    if (image.format.group != ImageFormatGroup.yuv420) {
      debugPrint('Unsupported image format: \${image.format.group}');
      return null;
    }

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final imageRotation = InputImageRotationValue.fromRawValue(
      description.sensorOrientation,
    );
    if (imageRotation == null) return null;

    const inputImageFormat = InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  @override
  void dispose() {
    _controller.dispose();
    _poseDetector.close();
    _iosTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: CameraPreview(_controller),
              ),
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: CustomPaint(
                painter: PosePainter(
                  _poses,
                  _controller.value.previewSize!,
                  _controller.description.sensorOrientation,
                ),
                child: Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size previewSize;
  final int sensorOrientation;

  PosePainter(this.poses, this.previewSize, this.sensorOrientation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 4;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final textStyle = TextStyle(color: Colors.green, fontSize: 12);

    final isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final imageWidth = isRotated ? previewSize.height : previewSize.width;
    final imageHeight = isRotated ? previewSize.width : previewSize.height;

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    final connections = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    ];

    for (final pose in poses) {
      final landmarks = pose.landmarks;

      void drawLabel(String label, Offset offset) {
        textPainter.text = TextSpan(text: label, style: textStyle);
        textPainter.layout();
        textPainter.paint(canvas, offset);
      }

      Offset transform(PoseLandmark l) {
        double x = l.x;
        double y = l.y;

        if (isRotated) {
          final temp = x;
          x = y;
          y = temp;
        }

        x = x * scaleX;
        y = y * scaleY;

        x = size.width - x;

        return Offset(x, y);
      }

      for (final entry in landmarks.entries) {
        final offset = transform(entry.value);
        canvas.drawCircle(offset, 6, paint);
        drawLabel(entry.key.name, offset);
      }

      for (final connection in connections) {
        final p1 = landmarks[connection[0]];
        final p2 = landmarks[connection[1]];
        if (p1 != null && p2 != null) {
          final point1 = transform(p1);
          final point2 = transform(p2);
          canvas.drawLine(point1, point2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
