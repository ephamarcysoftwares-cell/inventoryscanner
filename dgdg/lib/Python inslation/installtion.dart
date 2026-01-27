import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==============================================================================
// 🎯 INTERNAL FUNCTION: _installFlask (IMPROVED)
// Installs the Flask dependency using pip, preferring 'python -m pip'.
// ==============================================================================
// ==============================================================================
// 🎯 INTERNAL FUNCTION: _installFlask (MODIFIED to use only 'pip')
// Installs the Flask dependency using pip.
// ==============================================================================
Future<void> _installFlask() async {
  print('Installing Flask dependency...');
  try {
    // NOTE: Using 'pip' directly is less reliable than 'python -m pip'
    // if the Scripts directory is not correctly in the PATH.
    final pipResult = await Process.run('pip', ['install', 'flask']);

    if (pipResult.exitCode == 0) {
      print('Flask installed successfully.');
    } else {
      print('Flask installation failed. Ensure pip is in PATH.');
      print('Stderr: ${pipResult.stderr}');

      // 💡 Retaining the most reliable command as a fallback for maximum success chance
      if (Platform.isWindows) {
        print('Attempting fallback with the reliable "python -m pip" command...');
        final fallbackResult = await Process.run('python', ['-m', 'pip', 'install', 'flask']);
        if (fallbackResult.exitCode == 0) {
          print('Flask installed successfully via reliable fallback.');
          return;
        }
        print('Fallback command also failed. Stderr: ${fallbackResult.stderr}');
      }
    }
  } catch (e) {
    print('Failed to run pip install flask. Error: $e');
  }
}

// ==============================================================================
// 🎯 EXPORTED FUNCTION: installPythonAndDependencies
// Handles download, silent installation of Python (if needed), and pip install flask.
// ==============================================================================
Future<void> installPythonAndDependencies() async {
  if (!Platform.isWindows) {
    print('Python dependency auto-installer is only supported on Windows.');
    return;
  }

  // NOTE: This URL is for a specific Python version (3.12.1 64-bit)
  const pythonInstallerUrl = 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe';
  const installPath = 'C:\\Users\\Public\\epharmacy\\python_installer.exe';
  final installerFile = File(installPath);

  // Ensure the directory for the installer exists
  final installerDir = Directory('C:\\Users\\Public\\epharmacy');
  if (!await installerDir.exists()) {
    await installerDir.create(recursive: true);
  }

  try {
    print('Checking for existing Python installation...');
    final result = await Process.run('python', ['--version']);
    if (result.exitCode == 0 && result.stdout.toString().contains('Python 3')) {
      print('Python detected: ${result.stdout.trim()}. Skipping installation.');
      await _installFlask();
      return;
    }
  } catch (_) {
    print('Python not found. Starting installation process.');
  }

  try {
    print('Downloading Python installer from: $pythonInstallerUrl');
    final response = await http.get(Uri.parse(pythonInstallerUrl));
    if (response.statusCode != 200) {
      print('Failed to download Python installer: ${response.statusCode}');
      return;
    }

    await installerFile.writeAsBytes(response.bodyBytes);
    print('Installer downloaded to $installPath');

    // Arguments for a silent, all-users install that adds Python to PATH
    final installArgs = [
      '/quiet',
      'InstallAllUsers=1',
      'PrependPath=1',
    ];

    print('Starting Python silent installation. This may take a few minutes...');
    // Running the downloaded installer
    final installResult = await Process.run(installPath, installArgs);

    if (installResult.exitCode == 0) {
      print('Python installation completed successfully.');
      // Give the system a moment to update the PATH environment variable
      await Future.delayed(const Duration(seconds: 5));
      await _installFlask();
    } else {
      print('Python installation failed. Exit code: ${installResult.exitCode}');
      print('Stderr: ${installResult.stderr}');
    }

    // Clean up the installer file
    if (await installerFile.exists()) {
      await installerFile.delete();
    }
  } catch (e) {
    print('Error during Python installation process: $e');
  }
}

// ==============================================================================
// 🎯 PYTHON SERVER SETUP FUNCTION (IMPROVED with pythonw fallback)
// ==============================================================================
Future<void> startPythonServer() async {
  // CRITICAL: Ensure this path matches the DB directory logic in the Python script
  const String dbDir = 'C:\\Users\\Public\\epharmacy';
  const String networkDir = '$dbDir\\network';
  const String serverFilePath = '$networkDir\\server.py';

  // 1. Server Script URL
  const String serverScriptUrl = 'https://ephamarcysoftware.co.tz/admin/uploads/material/server.py';

  // 2. Platform Check (Server only runs on Windows)
  if (!Platform.isWindows) {
    print('Python server is not required for this platform.');
    return;
  }

  try {
    // 3. Create the directories
    final networkDirObj = Directory(networkDir);
    if (!await networkDirObj.exists()) {
      await networkDirObj.create(recursive: true);
      print('Created network directory: $networkDir');
    }

    // 4. Download and Write the Python server script
    final serverFile = File(serverFilePath);
    print('Downloading server script from: $serverScriptUrl...');

    // Perform the HTTP GET request to download the file
    final response = await http.get(Uri.parse(serverScriptUrl));

    if (response.statusCode == 200) {
      // Save the downloaded content to the local file path
      await serverFile.writeAsString(response.body);
      print('Successfully downloaded and wrote server.py to: $serverFilePath');
    } else {
      print('ERROR: Failed to download server.py. Status Code: ${response.statusCode}');
      // CRITICAL: If download fails, we cannot start the server, so we exit.
      return;
    }

    // 5. Start the Python server
    // 💡 IMPROVEMENT: Try 'pythonw' first, but if it throws an error (like "not found"),
    // catch the error and try again with the more reliable 'python'.
    final pythonwExecutable = 'pythonw';
    final pythonExecutable = 'python';

    try {
      print('Attempting to start Python server using $pythonwExecutable...');
      // Try pythonw first (silent mode)
      await Process.start(
        pythonwExecutable,
        [serverFilePath],
        runInShell: true,
      ).then((process) {
        // Log streams for debugging
        process.stderr.listen((data) {
          print('Python Server ERROR (pythonw): ${String.fromCharCodes(data)}');
        });
        process.stdout.listen((data) {}); // Suppress stdout for pythonw
        print('Successfully started Python server process on port 5005 (via $pythonwExecutable).');
      }).catchError((e) {
        // If pythonw fails to start (e.g., Command not found)
        print('Failed to start with $pythonwExecutable. Error: $e');
        throw e; // Re-throw to be caught by the outer catch block
      });
    } catch (e) {
      // Fallback to 'python' (will open a console window)
      print('Falling back to $pythonExecutable...');
      await Process.start(
        pythonExecutable,
        [serverFilePath],
        runInShell: true,
      ).then((process) {
        // Log streams for debugging
        process.stderr.listen((data) {
          print('Python Server ERROR (python): ${String.fromCharCodes(data)}');
        });
        process.stdout.listen((data) {
          print('Python Server Output: ${String.fromCharCodes(data)}');
        });
        print('Successfully started Python server process on port 5005 (via $pythonExecutable).');
      }).catchError((e) {
        print('Error starting Python server with $pythonExecutable. Final Error: $e');
      });
    }

  } catch (e) {
    print('CRITICAL: Failed to setup, download, or start Python server: $e');
  }
}


// ==============================================================================
// 🎯 MAIN APPLICATION
// ==============================================================================
void main() async {
  // Must be called before using any Flutter widgets or services
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Install Python and Flask dependencies safely before running the app
  await installPythonAndDependencies();

  // 2. Start the Python Flask Server (This will now download the script)
  await startPythonServer();

  runApp(const MyApp());
}

// ==============================================================================
// 🎯 ROOT WIDGET
// ==============================================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Pharmacy Software',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

// ==============================================================================
// 🎯 HOME SCREEN (with 1-minute Timer check, download, and restart)
// ==============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String serverStatus = 'Checking server status...';
  // Timer object for the recurring check
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // 1. Initial check immediately
    _checkServerStatus();
    // 2. Set up the recurring timer to run every 1 minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // autoRestart=true tells the function to attempt download/start on failure
      _checkServerStatus(autoRestart: true);
    });
  }

  // Dispose of the timer when the widget is removed
  @override
  void dispose() {
    _timer.cancel(); // Stop the timer when the widget is gone
    super.dispose();
  }

  // Function to ping the server and restart if necessary
  Future<void> _checkServerStatus({bool autoRestart = false}) async {
    if (!mounted) return;

    // The server runs on 0.0.0.0, which means it's accessible via 127.0.0.1 (localhost)
    const url = 'http://127.0.0.1:5005/medicines';

    String newStatus;
    bool needsRestart = false;

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        newStatus = 'Server is RUNNING and operational (200 OK).';
      } else if (response.statusCode == 500) {
        newStatus = 'Server is RUNNING, but DB connection failed (500 Error).';
      } else {
        newStatus = 'Server is RUNNING, but returned: ${response.statusCode}';
      }

    } on TimeoutException {
      newStatus = 'Server check timed out. Attempting restart...';
      needsRestart = true;
    } catch (e) {
      // Catch exceptions like SocketException (connection refused)
      newStatus = 'Failed to connect to server. Attempting restart...';
      needsRestart = true;
    }

    if (autoRestart && needsRestart) {
      print('Server check failed, attempting to download and restart Python server...');
      // This call performs the download and start logic
      await startPythonServer();
      // Wait briefly for the server to spin up, then check again
      await Future.delayed(const Duration(seconds: 3));
      // Run a verification check (without triggering a restart loop)
      await _checkServerStatus();
      return;
    }

    if (serverStatus != newStatus && mounted) {
      setState(() {
        serverStatus = newStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Pharmacy Home'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Welcome to E-Pharmacy Software!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Local Server Status:',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                serverStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  // Use color based on status
                  color: serverStatus.contains('RUNNING') ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              // This button will run an immediate, manual check
              ElevatedButton(
                onPressed: () => _checkServerStatus(),
                child: const Text('Manual Re-check Server Status'),
              ),
              const SizedBox(height: 10),
              // This button will manually trigger the server start
              ElevatedButton(
                onPressed: () async {
                  await startPythonServer(); // Force download and start
                  await _checkServerStatus();
                },
                child: const Text('Force Start Server (and Re-download)'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Note: Server status is checked automatically every 1 minute. If it fails, the system downloads the latest script and restarts.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}