import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class CameraStreamPage extends StatefulWidget {
  @override
  _CameraStreamPageState createState() => _CameraStreamPageState();
}

class _CameraStreamPageState extends State<CameraStreamPage> {
  late VlcPlayerController _videoPlayerController;

  @override
  void initState() {
    super.initState();

    // Set the camera URL (replace this with the URL of your IP camera stream)
    String cameraUrl = 'http://192.168.217.69:8080/video';  // Your camera stream URL

    // Initialize the VLC player controller
    _videoPlayerController = VlcPlayerController.network(
      cameraUrl,
      autoPlay: true,  // Auto-play the stream
      options: VlcPlayerOptions(),  // Additional options can be set here
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();  // Clean up the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera Stream')),
      body: Center(
        child: VlcPlayer(
          controller: _videoPlayerController,  // Pass the controller here
          aspectRatio: 16 / 9,  // Adjust the aspect ratio based on your stream's resolution
          virtualDisplay: true,  // Use virtual display for desktop (this works for Flutter desktop)
        ),
      ),
    );
  }
}
