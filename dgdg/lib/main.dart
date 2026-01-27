import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'splash_screen.dart';

// -----------------------------------------------------------------------------
// GLOBAL STATE
// -----------------------------------------------------------------------------
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const Color primaryPurple = Color(0xFF673AB7);

bool _isUpdateCheckInProgress = false;
bool _isDownloading = false;
bool _isDialogOpen = false;
double _downloadProgress = 0;

// -----------------------------------------------------------------------------
// HTTP OVERRIDE (SSL)
// -----------------------------------------------------------------------------
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return client;
  }
}

// -----------------------------------------------------------------------------
// MAIN
// -----------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  }

  await Supabase.initialize(
    url: 'https://tfqbfzllkducffjoeqsi.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRmcWJmemxsa2R1Y2Zmam9lcXNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5MDcxMDUsImV4cCI6MjA4MTQ4MzEwNX0.oH-Wh-6rfgpcYjX-1jw2j4s9jrvCbVIJ9_iBg7hW1D0',
  );

  runApp(const MyApp());

  Future.delayed(const Duration(seconds: 5), checkForUpdates);
}

// -----------------------------------------------------------------------------
// UPDATE DISPATCHER
// -----------------------------------------------------------------------------
Future<void> checkForUpdates() async {
  if (_isUpdateCheckInProgress) return;
  _isUpdateCheckInProgress = true;

  try {
    if (Platform.isWindows) {
      await _checkWindowsUpdate();
    } else if (Platform.isAndroid) {
      await _checkAndroidUpdate();
    }
  } finally {
    _isUpdateCheckInProgress = false;
  }
}

// -----------------------------------------------------------------------------
// ANDROID UPDATE
// -----------------------------------------------------------------------------
Future<void> _checkAndroidUpdate() async {
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      await InAppUpdate.performImmediateUpdate();
    }
  } catch (e) {
    debugPrint("Android update error: $e");
  }
}

// -----------------------------------------------------------------------------
// WINDOWS UPDATE
// -----------------------------------------------------------------------------
Future<void> _checkWindowsUpdate() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    final data = await Supabase.instance.client
        .from('app_settings')
        .select()
        .maybeSingle();

    if (data == null) return;

    final latestVersion = data['windows_latest_version'];
    final downloadUrl = data['windows_download_url'];
    final releaseNotes =
        data['release_notes'] ?? "Maboresho ya mfumo na usalama.";

    if (_isNewVersionAvailable(currentVersion, latestVersion)) {
      _showWindowsUpdateDialog(downloadUrl, latestVersion, releaseNotes);
    }
  } catch (e) {
    debugPrint("Windows update error: $e");
  }
}

bool _isNewVersionAvailable(String current, String server) {
  try {
    final c = current.split('.').map(int.parse).toList();
    final s = server.split('.').map(int.parse).toList();
    for (int i = 0; i < s.length; i++) {
      final cv = i < c.length ? c[i] : 0;
      if (s[i] > cv) return true;
      if (s[i] < cv) return false;
    }
  } catch (_) {
    return current != server;
  }
  return false;
}

// -----------------------------------------------------------------------------
// WINDOWS UPDATE DIALOG
// -----------------------------------------------------------------------------
void _showWindowsUpdateDialog(String url, String version, String notes) {
  final context = navigatorKey.currentContext;
  if (context == null || _isDialogOpen) return;

  _isDialogOpen = true;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          _isDownloading
              ? "Inapakua Maboresho..."
              : "Update Inapatikana ($version)",
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isDownloading) ...[
                const Text(
                  "Nini kipya:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(notes),
                const SizedBox(height: 15),
                const Text("Ungependa kusasisha sasa?"),
              ] else ...[
                LinearProgressIndicator(
                  value: _downloadProgress,
                  color: primaryPurple,
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "${(_downloadProgress * 100).toStringAsFixed(0)}%",
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!_isDownloading) ...[
            TextButton(
              onPressed: () {
                _isDialogOpen = false;
                Navigator.pop(context); // ❗ no exit
              },
              child: const Text("BAADAE"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
              ),
              onPressed: () async {
                setState(() => _isDownloading = true);
                await _downloadAndInstallWindows(url, setState);
              },
              child: const Text(
                "UPDATE SASA",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    ),
  ).then((_) => _isDialogOpen = false);
}

// -----------------------------------------------------------------------------
// DOWNLOAD + INSTALL (WINDOWS)
// -----------------------------------------------------------------------------
Future<void> _downloadAndInstallWindows(
    String url,
    StateSetter setState,
    ) async {
  try {
    final dir = await getTemporaryDirectory();
    final installerPath = p.join(dir.path, "StockUpdate_Setup.exe");

    await Dio().download(
      url,
      installerPath,
      onReceiveProgress: (r, t) {
        if (t > 0) {
          setState(() => _downloadProgress = r / t);
        }
      },
    );

    await windowManager.setPreventClose(false);

    final exeName =
        Platform.executable.split(Platform.pathSeparator).last;

    final command =
        'taskkill /F /IM "$exeName" /T && timeout /t 2 && start "" "$installerPath"';

    await Process.start(
      'cmd',
      ['/c', command],
      runInShell: true,
      mode: ProcessStartMode.detached,
    );

    exit(0); // ✅ allowed here
  } catch (e) {
    debugPrint("Install error: $e");
    setState(() {
      _isDownloading = false;
      _downloadProgress = 0;
    });
    _isDialogOpen = false;
  }
}

// -----------------------------------------------------------------------------
// APP ROOT
// -----------------------------------------------------------------------------
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_isDialogOpen || _isDownloading) {
      return; // ❗ DO NOT EXIT
    }

    final shouldClose =
    await _onWillPop(navigatorKey.currentContext!);

    if (shouldClose) {
      await windowManager.setPreventClose(false);
      exit(0);
    }
  }

  Future<bool> _onWillPop(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Funga Programu"),
        content: const Text("Unataka kufunga programu?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("HAPANA"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              windowManager.setPreventClose(false).then((_) {
                exit(0);
              });
            },
            child: const Text(
              "NDIO",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryPurple,
      ),
      home: const SplashScreen(),
    );
  }
}
