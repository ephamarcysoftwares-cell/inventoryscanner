import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';


class UpdateService {
  final String versionUrl =
      'https://ephamarcysoftware.co.tz/admin/uploads/version.json';
  late String currentVersion;

  static const String _lastCheckKey = 'last_update_check_timestamp';
  static const String _downloadInProgressKey = 'download_in_progress';

  // Initialize current app version
  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    currentVersion = info.version;
    debugPrint('Current app version: $currentVersion');
  }

  // Check for updates once per 24 hours
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
        debugPrint('⏳ Update already in progress. Skipping.');
        return;
      }

      if (lastCheckMillis != null) {
        final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);
        if (now.difference(lastCheck).inHours < 24) {
          debugPrint('🕒 Update check skipped (<24h).');
          return;
        }
      }
    }

    await prefs.setInt(_lastCheckKey, now.millisecondsSinceEpoch);
    await prefs.setBool(_downloadInProgressKey, true);

    try {
      await _checkUpdate(onProgress: onProgress);
    } catch (e) {
      rethrow;
    } finally {
      await prefs.setBool(_downloadInProgressKey, false);
    }
  }

  Future<void> _checkUpdate({ValueChanged<double>? onProgress}) async {
    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch version info: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final latestVersion = data['version'] as String;

      String? downloadUrl;

      if (Platform.isWindows) {
        downloadUrl = data['url'] as String;
      } else if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final is64bit =
        androidInfo.supportedAbis.any((abi) => abi.contains('64'));
        downloadUrl =
        is64bit ? data['apk_64'] as String : data['apk_32'] as String;
      } else {
        debugPrint('Unsupported platform for update.');
        return;
      }

      if (_isNewerVersion(latestVersion, currentVersion) &&
          downloadUrl != null) {
        debugPrint('🚨 New version available: $latestVersion');
        await _downloadAndInstall(downloadUrl, onProgress: onProgress);
      } else {
        debugPrint('✅ App is up to date.');
      }
    } catch (e) {
      rethrow;
    }
  }

  bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();
    for (int i = 0; i < latestParts.length; i++) {
      final l = latestParts[i] ?? 0;
      final c = i < currentParts.length ? currentParts[i] ?? 0 : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  Future<void> _downloadAndInstall(String url,
      {ValueChanged<double>? onProgress}) async {
    const maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      try {
        final dir = await getTemporaryDirectory();
        final fileName =
        Platform.isWindows ? 'StockInventoryInstaller.exe' : 'StockInventory.apk';
        final filePath = '${dir.path}/$fileName';
        final file = File(filePath);

        if (await file.exists()) await file.delete();

        debugPrint('🔽 Download attempt #$attempt from $url');

        final encodedUrl = Uri.encodeFull(url); // fix & and spaces
        final request = await HttpClient().getUrl(Uri.parse(encodedUrl));
        final response = await request.close();

        if (response.statusCode != 200) {
          debugPrint('❌ HTTP ${response.statusCode} error. Retrying...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        final totalSize = response.contentLength;
        int received = 0;
        final sink = file.openWrite();

        await for (var chunk in response) {
          received += chunk.length;
          sink.add(chunk);

          if (onProgress != null && totalSize != null && totalSize > 0) {
            onProgress(received / totalSize);
          }
        }

        await sink.flush();
        await sink.close();

        debugPrint('✅ Download complete: $filePath');

        if (Platform.isWindows) {
          await Process.start('cmd', ['/c', 'start', '', filePath],
              runInShell: true);
        } else if (Platform.isAndroid) {

        }

        exit(0);
      } catch (e) {
        debugPrint('❌ Download attempt #$attempt failed: $e');
        if (attempt >= maxRetries) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }
}
