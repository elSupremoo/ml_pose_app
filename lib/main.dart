import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _controller = CameraController(_cameras[0], ResolutionPreset.medium);
    await _controller.initialize();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

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
        debugPrint("Pose detection error: $e");
      }

      _isDetecting = false;
    });
    setState(() {});
  }

  InputImage? _cameraImageToInputImage(
    CameraImage image,
    CameraDescription description,
  ) {
    if (Platform.isIOS || image.format.group != ImageFormatGroup.yuv420) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        CameraPreview(_controller),
        CustomPaint(painter: PosePainter(_poses)),
      ],
    );
  }
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;

  PosePainter(this.poses);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 4;

    for (final pose in poses) {
      final landmarks = pose.landmarks;

      for (final entry in landmarks.entries) {
        final x = entry.value.x;
        final y = entry.value.y;
        canvas.drawCircle(Offset(x, y), 6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
