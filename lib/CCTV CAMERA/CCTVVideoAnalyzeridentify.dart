// import 'package:flutter/material.dart';
// import 'package:flutter_vlc_player/flutter_vlc_player.dart';
//
// import 'CCTVVideoAnalyzer.dart';
//   // Import the CCTVVideoAnalyzer class
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'CCTV Sales Analyzer',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: CCTVViewer(),
//     );
//   }
// }
//
// class CCTVViewer extends StatefulWidget {
//   @override
//   _CCTVViewerState createState() => _CCTVViewerState();
// }
//
// class _CCTVViewerState extends State<CCTVViewer> {
//   CCTVVideoAnalyzer _analyzer = CCTVVideoAnalyzer();
//   String _saleData = 'No Sales Yet';
//
//   @override
//   void initState() {
//     super.initState();
//     _analyzer.initialize('rtsp://your-cctv-url'); // Replace with your RTSP URL
//     _analyzer.startCapture();  // Start auto capturing and analyzing
//   }
//
//   @override
//   void dispose() {
//     _analyzer.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('CCTV Sales Analyzer'),
//       ),
//       body: Column(
//         children: [
//           // Video Player
//           Expanded(
//             child: VlcPlayer(
//               controller: _analyzer._controller!,
//               aspectRatio: 16 / 9,
//               virtualDisplay: true,
//             ),
//           ),
//           // Display the net sales data
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Text(
//               'Net Sales: \$${_analyzer._netSales.toStringAsFixed(2)}',
//               style: TextStyle(fontSize: 18),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
