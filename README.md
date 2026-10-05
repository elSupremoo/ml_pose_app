# ml_pose_app

A cross-platform (Android / iOS) Flutter app that runs **real-time, on-device human pose estimation** on a live camera feed and draws the detected skeleton next to the preview.

It uses Google ML Kit's pretrained pose detector (`google_mlkit_pose_detection`). The model is not trained or fine-tuned here; the project is about the camera-to-model pipeline and the rendering around it.

## What it does

- Opens with two guided intro screens (`lib/demo.dart`) showing how to position yourself and the camera (side-on, then ~45 degrees), then starts the live view.
- Streams frames from the front camera and runs ML Kit pose detection in stream mode.
- Draws every detected landmark (with its name) and 12 bone connections (arms, legs, shoulders, hips, torso) on a separate canvas under the camera preview.
- Handles the platform differences in getting frames to the model:
  - **Android:** consumes the camera image stream, converts the YUV420 planes to NV21 and passes the sensor orientation as rotation metadata.
  - **iOS:** falls back to a capture loop (`takePicture` on a 20 ms timer) and feeds the file to the detector.
- Drops incoming frames while an inference is still running, so detection never queues up behind the camera.
- Maps model coordinates to screen space with a custom `CustomPainter`, accounting for sensor rotation (90/270), scaling and the selfie mirror.

## Project layout

| Path | Purpose |
|---|---|
| `lib/main.dart` | Camera setup, frame conversion, detection loop, `PosePainter` |
| `lib/demo.dart` | Intro screens that show the recommended camera/body positioning |
| `assets/` | Example positioning images used by the intro screens |
| `android/`, `ios/` | Platform runners |

## Running it

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.7.0`) and a **physical device** (the camera and ML Kit are not usable on most emulators).

```bash
flutter pub get
flutter run
```

Grant the camera permission when prompted.

## Dependencies

`camera`, `google_mlkit_pose_detection`, `google_mlkit_commons`, `permission_handler`, `flutter_spinkit`.

## Known limitations

- Small prototype; no unit tests beyond the default widget test.
- The iOS capture loop is slower than the Android image stream.
- Only the front camera is used, and no accuracy or FPS benchmarks have been measured yet.
- Landmark labels are drawn for every point, which gets busy on screen.

## Possible next steps

- Benchmark latency/FPS per platform and add a metrics overlay.
- Compute joint angles and use them for simple exercise/form feedback.
- Record landmark time series for offline analysis.
