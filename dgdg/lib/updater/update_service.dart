import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
// Note: process_run needs to be imported if you are using shell (assuming a shim or package usage)
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  final String versionUrl = 'https://ephamarcysoftware.co.tz/admin/uploads/version.json';
  late String currentVersion;

  static const String _lastCheckKey = 'last_update_check_timestamp';
  static const String _downloadInProgressKey = 'download_in_progress';

  // Initialize version info
  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    currentVersion = info.version;
    print('Current app version: $currentVersion');
  }

  // Run update check only once per 24 hours (unless forced)
  Future<void> checkForUpdatesOncePer24Hours({
    bool force = false,
    ValueChanged<double>? onProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (!force) {
      final lastCheckMillis = prefs.getInt(_lastCheckKey);
      final inProgress = prefs.getBool(_downloadInProgressKey) ?? false;

      if (inProgress) {
        print('⏳ Update already in progress or was interrupted. Skipping.');
        return;
      }

      if (lastCheckMillis != null) {
        final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);
        final difference = now.difference(lastCheck);
        if (difference.inHours < 24) {
          print('🕒 Update check skipped. Last checked ${difference.inHours} hours ago.');
          return;
        }
      }
    }

    await prefs.setInt(_lastCheckKey, now.millisecondsSinceEpoch);
    await prefs.setBool(_downloadInProgressKey, true);

    try {
      await checkForUpdates(onProgress: onProgress);
    } catch (e) {
      // Re-throw the error to be caught and logged in main.dart
      rethrow;
    } finally {
      await prefs.setBool(_downloadInProgressKey, false);
    }
  }

  // Main version check logic
  Future<void> checkForUpdates({ValueChanged<double>? onProgress}) async {
    try {
      final response = await http.get(Uri.parse(versionUrl));

      if (response.statusCode == 200) {
        try {
          // 🚨 CRITICAL FIX: This inner try-catch specifically handles the JSON failure.
          final Map<String, dynamic> data = json.decode(response.body);

          String latestVersion = data['version'];
          String downloadUrl = data['url'];

          if (_isNewerVersion(latestVersion, currentVersion)) {
            print('🚨 New version available: $latestVersion');
            await _downloadAndInstall(downloadUrl, onProgress: onProgress);
          } else {
            print('✅ You are running the latest version: $currentVersion');
          }
        } on FormatException catch (e) {
          // --- DIAGNOSTIC LOGGING ADDED HERE ---
          print('❌ Update check FAILED: Server returned malformed JSON!');
          String bodyPreview = response.body.length > 50
              ? response.body.substring(0, 50) + '...'
              : response.body;

          print('Bad Response (First 50 chars): $bodyPreview');
          // ------------------------------------

          // Re-throw the error with a descriptive message
          throw Exception('Failed to decode version info (FormatException): $e');
        }
      } else {
        print('❌ Failed to fetch version info: HTTP ${response.statusCode}');
        // Throw an error for non-200 status codes as well
        throw Exception('Failed to fetch version info: HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Catch network or general errors and re-throw
      rethrow;
    }
  }

  // Compare semantic versions
  bool _isNewerVersion(String latest, String current) {
    List<String> latestParts = latest.split('.');
    List<String> currentParts = current.split('.');
    for (int i = 0; i < latestParts.length; i++) {
      int latestNum = int.tryParse(latestParts[i]) ?? 0;
      int currentNum = i < currentParts.length ? int.tryParse(currentParts[i]) ?? 0 : 0;
      if (latestNum > currentNum) return true;
      if (latestNum < currentNum) return false;
    }
    return false;
  }

  // Download and install the new version robustly
  Future<void> _downloadAndInstall(String url, {ValueChanged<double>? onProgress}) async {
    const maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      try {
        if (!Platform.isWindows) {
          print('❌ Installer only supported on Windows.');
          throw UnsupportedError('Installer only supported on Windows.');
        }

        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/StockInventoryInstaller.exe';
        final file = File(filePath);

        if (await file.exists()) await file.delete();

        print('🔽 Starting download attempt #$attempt from $url');

        final request = await HttpClient().getUrl(Uri.parse(url));
        final response = await request.close();

        if (response.statusCode != 200) {
          print('❌ HTTP ${response.statusCode} error. Retrying...');
          continue;
        }

        final totalSize = response.contentLength;

        int received = 0;
        final sink = file.openWrite();

        // Timeout management using Completer
        final Completer<void> downloadCompleter = Completer<void>();
        final Timer stallTimer = Timer(const Duration(seconds: 60), () {
          if (!downloadCompleter.isCompleted) {
            downloadCompleter.completeError(Exception('Download stalled for 60 seconds.'));
          }
        });

        try {
          await for (var chunk in response.timeout(const Duration(minutes: 5), onTimeout: (sink) {
            throw TimeoutException('Download timeout after 5 minutes.');
          })) {
            received += chunk.length;
            sink.add(chunk);

            // Re-schedule the stall timer
            stallTimer.cancel();
            Timer(const Duration(seconds: 60), () {
              if (!downloadCompleter.isCompleted) {
                downloadCompleter.completeError(Exception('Download stalled for 60 seconds.'));
              }
            });

            if (onProgress != null && totalSize != null && totalSize > 0) {
              onProgress(received / totalSize);
            }
          }
          downloadCompleter.complete();
        } catch (e) {
          if (!downloadCompleter.isCompleted) downloadCompleter.completeError(e);
        } finally {
          stallTimer.cancel();
          await sink.flush();
          await sink.close();
        }

        await downloadCompleter.future;

        final downloadedSize = await file.length();
        print('✅ Download complete. File size: $downloadedSize bytes');

        if (totalSize != null && totalSize > 0 && downloadedSize != totalSize) {
          print('⚠️ File size mismatch ($downloadedSize != $totalSize)! Retrying...');
          await file.delete();
          continue;
        }

        onProgress?.call(1.0);
        print('🚀 Launching installer...');
        await runExecutable(filePath);
        await Future.delayed(const Duration(milliseconds: 500));
        exit(0);
      } catch (e) {
        print('❌ Download attempt #$attempt failed: $e');
        if (attempt >= maxRetries) {
          print('❌ All download attempts failed.');
          rethrow;
        }
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  // Launch installer on Windows
  Future<void> runExecutable(String path) async {
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', path], runInShell: true);
      print('✅ Installer launched.');
    } else {
      throw UnsupportedError('Execution only supported on Windows.');
    }
  }
}