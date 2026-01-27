import 'package:flutter/material.dart';
 

void main() {
  runApp(MaterialApp(
    home: FFMPEGPlayerScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class FFMPEGPlayerScreen extends StatelessWidget {
  final String rtspUrl = "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov";

  get FFmpegKit => null;

  void snapshotVideo() async {
    String cmd = '-i "$rtspUrl" -frames:v 1 snapshot.jpg';
    await FFmpegKit.execute(cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("FFmpeg Snapshot")),
      body: Center(
        child: ElevatedButton(
          onPressed: snapshotVideo,
          child: Text("Take Snapshot from RTSP"),
        ),
      ),
    );
  }
}
