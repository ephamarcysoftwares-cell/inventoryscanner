import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:wifi_iot/wifi_iot.dart';
 // Updated Wi-Fi IOT package for scanning networks

class CCTVConnectionScreen extends StatefulWidget {
  @override
  _CCTVConnectionScreenState createState() => _CCTVConnectionScreenState();
}

class _CCTVConnectionScreenState extends State<CCTVConnectionScreen> {
  TextEditingController ipController = TextEditingController();
  TextEditingController deviceNameController = TextEditingController();
  TextEditingController serialNumberController = TextEditingController();
  VlcPlayerController? _vlcPlayerController;
  bool isLoading = false;
  String errorMessage = '';
  List<String> availableNetworks = [];

  @override
  void initState() {
    super.initState();
    _scanWiFiNetworks(); // Start scanning when the screen loads
  }

  // Function to scan available Wi-Fi networks
  // Function to scan available Wi-Fi networks
  Future<void> _scanWiFiNetworks() async {
    try {
      var networks = await WiFiForIoTPlugin.loadWifiList(); // Scanning Wi-Fi networks
      setState(() {
        availableNetworks = networks.map((network) => network.ssid ?? '').toList(); // Ensure non-null values
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to scan networks: $e';
      });
    }
  }

  // Function to connect to a selected Wi-Fi network
  Future<void> _connectToWiFi(String networkSSID, String password) async {
    try {
      await WiFiForIoTPlugin.connect(networkSSID, password: password);
      setState(() {
        errorMessage = 'Connected to $networkSSID';
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to connect to $networkSSID: $e';
      });
    }
  }

  // Function to manually connect to CCTV
  Future<void> connectToCCTV(String ip) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Test connection by pinging the device
      await _pingDevice(ip);
      // If successful, proceed to play the RTSP stream
      String rtspUrl = 'rtsp://$ip:554/stream';  // Adjust as per your camera's stream URL
      _initializeVLCPlayer(rtspUrl);
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to connect: $e';
        isLoading = false;
      });
    }
  }

  // Function to ping the device
  Future<void> _pingDevice(String ip) async {
    try {
      final result = await Process.run('ping', ['-c', '1', ip]);
      if (result.exitCode != 0) {
        throw Exception('Device not reachable at $ip');
      }
    } catch (e) {
      throw Exception('Error pinging $ip: $e');
    }
  }

  // Initialize VLC player for RTSP stream
  void _initializeVLCPlayer(String rtspUrl) {
    _vlcPlayerController = VlcPlayerController.network(
      rtspUrl,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
    setState(() {
      isLoading = false;
    });
  }

  // Auto-discovery (Network Scanning)
  Future<void> autoDiscoverDevices(String subnet) async {
    for (int i = 1; i <= 254; i++) {
      String ip = '$subnet$i';
      await _pingDevice(ip);
      // If the device is found, connect to it
      String rtspUrl = 'rtsp://$ip:554/stream';  // Adjust as per your camera's stream URL
      _initializeVLCPlayer(rtspUrl);
      break;  // Stop after finding the first device (remove `break` for scanning all)
    }
  }

  @override
  void dispose() {
    _vlcPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CCTV Camera Connection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: 'Enter IP Address',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: deviceNameController,
              decoration: InputDecoration(
                labelText: 'Enter Device Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: serialNumberController,
              decoration: InputDecoration(
                labelText: 'Enter Serial Number',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (ipController.text.isNotEmpty) {
                  connectToCCTV(ipController.text);
                } else {
                  setState(() {
                    errorMessage = 'Please enter an IP address';
                  });
                }
              },
              child: isLoading ? CircularProgressIndicator() : Text('Connect Manually'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  errorMessage = '';
                  isLoading = true;
                });
                autoDiscoverDevices('192.168.1.');
              },
              child: isLoading ? CircularProgressIndicator() : Text('Auto Discover Devices'),
            ),
            SizedBox(height: 20),
            Text(
              'Available Wi-Fi Networks:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ...availableNetworks.map((network) {
              return ListTile(
                title: Text(network),
                onTap: () {
                  // Connect to the selected Wi-Fi network
                  _connectToWiFi(network, 'password'); // Add a password input if needed
                },
              );
            }).toList(),
            SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: TextStyle(color: Colors.red),
              ),
            if (_vlcPlayerController != null)
              Container(
                height: 300,
                child: VlcPlayer(
                  controller: _vlcPlayerController!,
                  aspectRatio: 16 / 9,
                  virtualDisplay: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
