import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert'; // For SystemEncoding

// -----------------------------------------------------------------------------
// 🌐 Global Variables
// -----------------------------------------------------------------------------
Process? _serverProcess; // Reference to the Python process
List<String> logList = []; // Log messages for the UI
bool isServerRunning = false; // Tracks current state

// -----------------------------------------------------------------------------
// 🏁 Main Entry Point
// -----------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await startPythonServer(); // Start immediately
  monitorPythonServer(); // Periodic check

  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// 🧩 Utility Functions
// -----------------------------------------------------------------------------

/// Log helper for both console and UI
void logMessage(String message) {
  final now = DateTime.now().toIso8601String();
  final fullMsg = '[$now] $message';
  logList.insert(0, fullMsg); // newest first
  debugPrint(fullMsg);
}

/// Start or restart the Python server if not already running
/// Start or restart the Python server silently in background
Future<void> startPythonServer() async {
  try {
    const serverPath = r'C:\Users\Public\epharmacy\network\server.py';
    const workingDir = r'C:\Users\Public\epharmacy\network';

    if (_serverProcess != null) {
      logMessage('✅ Server already running (PID: ${_serverProcess!.pid})');
      return;
    }

    logMessage('🚀 Starting Python server in silent background...');

    final process = await Process.start(
      'python',
      [serverPath],
      workingDirectory: workingDir,
      runInShell: false, // important: no CMD window
      mode: ProcessStartMode.detachedWithStdio, // detached but still capture stdout/stderr
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );

    _serverProcess = process;
    isServerRunning = true;
    logMessage('✨ Server started successfully (PID: ${process.pid})');

    // Capture STDOUT
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      logMessage('SERVER STDOUT: ${data.trim()}');
    });

    // Capture STDERR
    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      logMessage('SERVER STDERR: ${data.trim()}');
    });

    // Detect when server stops
    process.exitCode.then((code) {
      logMessage('⚠️ Python server exited with code $code.');
      _serverProcess = null;
      isServerRunning = false;
    });
  } catch (e) {
    logMessage('❌ Failed to start server: $e');
    _serverProcess = null;
    isServerRunning = false;
  }
}


/// Stop the Python server
Future<void> stopPythonServer() async {
  if (_serverProcess != null) {
    logMessage('🛑 Stopping Python server (PID: ${_serverProcess!.pid})...');
    _serverProcess!.kill();
    _serverProcess = null;
    isServerRunning = false;
    logMessage('✅ Server stopped successfully.');
  } else {
    logMessage('⚠️ No server process to stop.');
  }
}

/// Periodic monitor (every 60s)
void monitorPythonServer() {
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    if (_serverProcess == null) {
      logMessage('🔄 Server not running — attempting restart...');
      await startPythonServer();
    } else {
      logMessage('✅ Server healthy. (Next check in 60s)');
    }
  });
}

// -----------------------------------------------------------------------------
// 🖥️ Flutter UI
// -----------------------------------------------------------------------------

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Timer _uiTimer;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {}); // Refresh logs
    });
  }

  @override
  void dispose() {
    _uiTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Pharmacy Server Monitor',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('E-Pharmacy Server Monitor'),
          backgroundColor: Colors.teal.shade900,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isServerRunning ? Colors.redAccent : Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(isServerRunning ? Icons.stop : Icons.play_arrow),
                label: Text(isServerRunning ? 'Stop Server' : 'Start Server'),
                onPressed: () async {
                  if (isServerRunning) {
                    await stopPythonServer();
                  } else {
                    await startPythonServer();
                  }
                  setState(() {}); // Refresh button color/state
                },
              ),
            ),
          ],
        ),
        body: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(10),
          child: ListView.builder(
            reverse: true, // Latest logs at top
            itemCount: logList.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 3.0),
                child: Text(
                  logList[index],
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
