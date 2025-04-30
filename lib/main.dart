import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as cam_pkg;
import 'package:flutter/services.dart';
import 'package:rtmp_broadcaster/camera.dart' as rtmp;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: StreamPage());
  }
}

class StreamPage extends StatefulWidget {
  @override
  _StreamPageState createState() => _StreamPageState();
}

class _StreamPageState extends State<StreamPage> {
  final _streamKeyController = TextEditingController();
  bool _isStreaming = false;
  bool _isCameraInitialized = false;
  rtmp.CameraController? _rtmpController;
  List<cam_pkg.CameraDescription>? _cameras;
  int? _selectedCameraIndex;

  @override
  Future<void> initState() async {
    super.initState();
    await _requestPermissions();
    _initializeCamera();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  rtmp.CameraLensDirection _mapLensDirection(
    cam_pkg.CameraLensDirection direction,
  ) {
    switch (direction) {
      case cam_pkg.CameraLensDirection.back:
        return rtmp.CameraLensDirection.back;
      case cam_pkg.CameraLensDirection.front:
        return rtmp.CameraLensDirection.front;
      case cam_pkg.CameraLensDirection.external:
        return rtmp.CameraLensDirection.external;
      default:
        return rtmp.CameraLensDirection.back;
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await cam_pkg.availableCameras();
      _selectedCameraIndex = _cameras!.indexWhere(
        (camera) => camera.lensDirection == cam_pkg.CameraLensDirection.back,
      );

      if (_selectedCameraIndex != -1) {
        final camera = _cameras![_selectedCameraIndex!];

        _rtmpController = rtmp.CameraController(
          rtmp.CameraDescription(
            // Use camera index instead of name
            name: _selectedCameraIndex!.toString(),
            lensDirection: _mapLensDirection(camera.lensDirection),
            sensorOrientation: camera.sensorOrientation,
          ),
          rtmp.ResolutionPreset.medium,
          enableAudio: true,
        );

        await _rtmpController!.initialize();
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      print("Camera initialization error: $e");
    }
  }

  Future<void> _toggleStream() async {
    if (_rtmpController == null) return;

    if (_isStreaming) {
      await _rtmpController!.stopVideoStreaming();
      setState(() => _isStreaming = false);
    } else {
      if (_streamKeyController.text.isEmpty) return;

      final url =
          'rtmp://a.rtmp.youtube.com/live2/${_streamKeyController.text}';

      await _rtmpController!.startVideoStreaming(url, bitrate: 2000);

      setState(() => _isStreaming = true);
    }
  }

  @override
  void dispose() {
    _rtmpController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Live Stream')),
      body: Column(
        children: [
          Expanded(
            child:
                _isCameraInitialized && _rtmpController != null
                    ? Stack(
                      fit: StackFit.expand,
                      children: [
                        // Camera preview as background
                        rtmp.CameraPreview(_rtmpController!),

                        // Custom overlay widgets
                        Positioned(
                          top: 20,
                          left: 20,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset(
                              'assets/yoursportz_logo.png',
                              width: 100,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                    : const Center(child: CircularProgressIndicator()),
          ),

          // Rest of your existing UI elements
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _streamKeyController,
              decoration: const InputDecoration(
                labelText: 'YouTube Stream Key',
                border: OutlineInputBorder(),
                hintText: 'Enter stream key here',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _rtmpController != null ? _toggleStream : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isStreaming ? Colors.red : Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
            child: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
