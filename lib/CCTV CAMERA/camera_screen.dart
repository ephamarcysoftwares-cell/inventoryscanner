import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';  // For camera permission

import '../DB/database_helper.dart';
import '../Dispensing/cart.dart';  // Your database helper file for inserting into the cart

class CameraScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CameraScreen({Key? key, required this.user}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  late List<CameraDescription> cameras;
  bool isCameraReady = false;
  String _ocrText = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // Initialize the camera and request permission
  Future<void> _initializeCamera() async {
    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      setState(() {
        _errorMessage = "Camera permission not granted!";
      });
      return;
    }

    try {
      // Get available cameras
      cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(cameras[0], ResolutionPreset.high);
        await _cameraController!.initialize();
        setState(() {
          isCameraReady = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error initializing camera: $e";
      });
    }
  }

  // Capture a picture and analyze it using OCR
  Future<void> _takePictureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Capture image from the camera
      final XFile picture = await _cameraController!.takePicture();
      String text = await FlutterTesseractOcr.extractText(picture.path);

      setState(() {
        _ocrText = text;
      });

      // For demonstration, assume OCR result contains "Medicine"
      if (_ocrText.contains("Medicine")) {
        _addMedicineToCart();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error processing image: $e";
      });
    }
  }

  // Add medicine data to the cart in the database
  void _addMedicineToCart() async {
    final db = await DatabaseHelper.instance.database;
    String currentDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // Dummy medicine data based on OCR results
    // Replace these values with actual parsing of OCR text
    await db.insert('cart', {
      'user_id': widget.user['id'],
      'medicine_name': 'Dummy Medicine Name',  // Replace with parsed OCR text
      'company': 'Dummy Company',              // Replace with parsed OCR text
      'price': 1000,                           // Replace with parsed OCR text
      'quantity': 1,
      'date_added': currentDate,
    });

    // Navigate to the cart page after adding
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera OCR'),
      ),
      body: isCameraReady
          ? Column(
        children: [
          _cameraController != null && _cameraController!.value.isInitialized
              ? CameraPreview(_cameraController!)
              : Center(child: Text('Camera not available')),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _takePictureAndAnalyze,
            child: Text('Take Picture & Analyze'),
          ),
          SizedBox(height: 20),
          Text('OCR Result: $_ocrText'),
          if (_errorMessage.isNotEmpty)
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.red),
            ),
        ],
      )
          : Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
