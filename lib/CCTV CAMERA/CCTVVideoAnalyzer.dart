// import 'dart:typed_data';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:image/image.dart' as img;
//
// class CCTVVideoAnalyzer {
//   CameraController? _cameraController;
//   Interpreter? _interpreter;
//   List<String> _productCatalog = ['Product1', 'Product2'];
//   List<double> _productPrices = [10.0, 20.0];
//   double _netSales = 0.0;
//
//   Future<void> initialize() async {
//     final cameras = await availableCameras();
//     final firstCamera = cameras.first;
//
//     _cameraController = CameraController(firstCamera, ResolutionPreset.medium);
//     await _cameraController?.initialize();
//
//     await loadModel();
//   }
//
//   Future<void> loadModel() async {
//     try {
//       _interpreter = await Interpreter.fromAsset('model.tflite');
//     } catch (e) {
//       print('Error loading model: $e');
//     }
//   }
//
//   void startCapture() {
//     _cameraController?.startImageStream((CameraImage image) {
//       analyzeFrame(image);
//     });
//   }
//
//   Future<void> analyzeFrame(CameraImage cameraImage) async {
//     try {
//       final img.Image rgbImage = _convertYUV420ToImage(cameraImage);
//
//       final input = preprocessImage(rgbImage); // Normalize + Resize
//
//       // Run inference
//       var output = List.filled(1, 0).reshape([1]);
//       _interpreter?.run(input.reshape([1, 224, 224, 3]), output);
//
//       handleSaleData(output);
//     } catch (e) {
//       print('Error analyzing frame: $e');
//     }
//   }
//
//   img.Image _convertYUV420ToImage(CameraImage image) {
//     final int width = image.width;
//     final int height = image.height;
//     final img.Image imgBuffer = img.Image(width: width, height: height);
//
//     final Plane planeY = image.planes[0];
//     final Plane planeU = image.planes[1];
//     final Plane planeV = image.planes[2];
//
//     final int uvRowStride = planeU.bytesPerRow;
//     final int uvPixelStride = planeU.bytesPerPixel ?? 1;
//
//     for (int y = 0; y < height; y++) {
//       for (int x = 0; x < width; x++) {
//         final int uvIndex =
//             uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
//         final int indexY = y * planeY.bytesPerRow + x;
//
//         final int yVal = planeY.bytes[indexY];
//         final int uVal = planeU.bytes[uvIndex];
//         final int vVal = planeV.bytes[uvIndex];
//
//         final r = (yVal + 1.403 * (vVal - 128)).clamp(0, 255).toInt();
//         final g =
//         (yVal - 0.344 * (uVal - 128) - 0.714 * (vVal - 128)).clamp(0, 255).toInt();
//         final b = (yVal + 1.770 * (uVal - 128)).clamp(0, 255).toInt();
//
//         imgBuffer.setPixelRgb(x, y, r, g, b);
//       }
//     }
//
//     return imgBuffer;
//   }
//
//   List<double> preprocessImage(img.Image image) {
//     final img.Image resized = img.copyResize(image, width: 224, height: 224);
//     final List<double> input = [];
//
//     for (int y = 0; y < 224; y++) {
//       for (int x = 0; x < 224; x++) {
//         final pixel = resized.getPixel(x, y);
//         input.add(pixel.r / 255.0);
//         input.add(pixel.g / 255.0);
//         input.add(pixel.b / 255.0);
//       }
//     }
//
//     return input;
//   }
//
//   void handleSaleData(List output) {
//     int detectedIndex = output[0];
//     double price = getPriceForItem(detectedIndex);
//     _netSales += price;
//     updateSaleInSystem();
//   }
//
//   double getPriceForItem(int index) {
//     if (index >= 0 && index < _productPrices.length) {
//       return _productPrices[index];
//     }
//     return 0.0;
//   }
//
//   void updateSaleInSystem() {
//     print('Total Net Sales: \$${_netSales.toStringAsFixed(2)}');
//   }
//
//   void dispose() {
//     _cameraController?.dispose();
//     _interpreter?.close();
//   }
// }
