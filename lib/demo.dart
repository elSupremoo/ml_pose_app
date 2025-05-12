import 'package:flutter/material.dart';
import 'package:ml_pose_app/main.dart';

class IntroScreens extends StatefulWidget {
  @override
  _IntroScreensState createState() => _IntroScreensState();
}

class _IntroScreensState extends State<IntroScreens> {
  int _index = 0;
  final List<String> _images = [
    'assets/pose_side.png',
    'assets/pose_angled.png',
  ];

  void _nextScreen() {
    if (_index < _images.length - 1) {
      setState(() => _index++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LiveCameraView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Image.asset(_images[_index])),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _index == 0
                    ? 'First sit on a chair with the full body visible like this and the camera directly to your side'
                    : 'Then sit like this with the camera about 45 degrees angle ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _nextScreen,
              child: Text(_index == _images.length - 1 ? 'Start' : 'Next'),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
