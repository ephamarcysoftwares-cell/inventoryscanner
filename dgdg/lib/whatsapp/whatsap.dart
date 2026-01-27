import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// IMPORTANT: Ensure you have the following packages in your pubspec.yaml:
// dependencies:
//   flutter:
//     sdk: flutter
//   http: ^0.13.3
//   shared_preferences: ^2.0.0

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profile Config',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: false,
      ),
      home: const WhatsAppConfigScreen(),
    );
  }
}

class WhatsAppConfigScreen extends StatefulWidget {
  const WhatsAppConfigScreen({super.key});

  @override
  _WhatsAppConfigScreenState createState() => _WhatsAppConfigScreenState();
}

class _WhatsAppConfigScreenState extends State<WhatsAppConfigScreen> {
  // --- CONSTANTS FOR DEFAULT CREDENTIALS ---
  static const String _defaultInstanceId = 'C9CB714B785A';
  static const String _defaultAccessToken = 'jOos7Fc3cE7gj2';

  // Controllers for the input fields
  final _instanceController = TextEditingController();
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController();

  // State variables for stored credentials and fetched data
  String _storedInstanceId = '';
  String _storedAccessToken = '';
  String _currentName = 'Not Loaded';
  String _presenceStatus = 'N/A'; // Stores the result from the presence check

  String _statusMessage = 'Initializing application...'; // Detailed API status

  @override
  void initState() {
    super.initState();
    _loadWhatsAppSettings();
  }

  @override
  void dispose() {
    _instanceController.dispose();
    _tokenController.dispose();
    _nameController.dispose();
    super.dispose();
  }

// -----------------------------------------------------------------
//                          SHARED PREFERENCES
// -----------------------------------------------------------------

  /// Loads saved instance ID and access token from local storage.
  /// If no credentials are saved, it uses the provided default values and saves them,
  /// but DOES NOT populate the text fields (to keep defaults hidden).
  Future<void> _loadWhatsAppSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedInstanceId = prefs.getString('whatsapp_instance_id');
    final savedAccessToken = prefs.getString('whatsapp_access_token');

    String finalInstanceId;
    String finalAccessToken;
    String loadMessage;
    bool usingDefaults = false;

    if (savedInstanceId == null || savedAccessToken == null || savedInstanceId.isEmpty || savedAccessToken.isEmpty) {
      // Case 1: No saved credentials found. Use defaults in the background.
      finalInstanceId = _defaultInstanceId;
      finalAccessToken = _defaultAccessToken;
      loadMessage = 'No user credentials saved. Using default keys for API calls. 🛡️';
      usingDefaults = true;

      // CRITICAL: Save the defaults so they are available for future sessions
      await prefs.setString('whatsapp_instance_id', finalInstanceId);
      await prefs.setString('whatsapp_access_token', finalAccessToken);
    } else {
      // Case 2: Saved credentials found. Use them.
      finalInstanceId = savedInstanceId;
      finalAccessToken = savedAccessToken;
      loadMessage = 'Saved user credentials loaded successfully. Ready to configure profile.';
    }

    // Update State (ALWAYS UPDATE internal variables)
    setState(() {
      _storedInstanceId = finalInstanceId;
      _storedAccessToken = finalAccessToken;

      _statusMessage = loadMessage;

      // Update Controllers (ONLY IF NOT USING DEFAULTS to keep fields blank)
      if (!usingDefaults) {
        _instanceController.text = _storedInstanceId;
        _tokenController.text = _storedAccessToken;
      }
    });
  }

  /// Saves the instance ID and access token to local storage.
  Future<void> _saveWhatsAppSettings() async {
    final instanceId = _instanceController.text.trim();
    final accessToken = _tokenController.text.trim();

    if (instanceId.isEmpty || accessToken.isEmpty) {
      _showSnackBar('Please enter both Instance ID and Access Token to save.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whatsapp_instance_id', instanceId);
    await prefs.setString('whatsapp_access_token', accessToken);

    setState(() {
      _storedInstanceId = instanceId;
      _storedAccessToken = accessToken;
      _statusMessage = 'WhatsApp credentials saved successfully! ✅';
    });
  }

// -----------------------------------------------------------------
//                          RETRY LOGIC
// -----------------------------------------------------------------

  /// Checks if the current stored credentials are the defaults. If not,
  /// it sets the defaults, saves them, and calls the original function to retry.
  Future<bool> _handleApiFailureAndRetry(Function originalFunction, String errorMessage) async {
    // Check if the current stored credentials are the default ones
    if (_storedInstanceId == _defaultInstanceId && _storedAccessToken == _defaultAccessToken) {
      setState(() {
        _statusMessage = 'API Error: $errorMessage. Default credentials failed. No retry possible. ❌';
      });
      _showSnackBar('API Failed: Default credentials are not working.');
      return false; // Already used defaults, no point in retrying
    }

    setState(() {
      _statusMessage = 'API Error: $errorMessage. Attempting to use default credentials and retry... 🔄';
    });

    // 1. Overwrite with default credentials
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whatsapp_instance_id', _defaultInstanceId);
    await prefs.setString('whatsapp_access_token', _defaultAccessToken);

    // 2. Update the in-memory state (do NOT update controllers to keep defaults hidden)
    setState(() {
      _storedInstanceId = _defaultInstanceId;
      _storedAccessToken = _defaultAccessToken;
    });

    _showSnackBar('Switching to default credentials and retrying operation...');

    // 3. Retry the original function
    // We wrap it in a function that returns the Future<void> version.
    await (originalFunction as Future<void> Function({bool isRetry}))(isRetry: true);

    return true;
  }

// -----------------------------------------------------------------
//                          API CALLS (GET)
// -----------------------------------------------------------------

  /// Sends a GET request to fetch the current business profile.
  Future<void> _loadCurrentProfile({bool isRetry = false}) async {
    if (_storedInstanceId.isEmpty || _storedAccessToken.isEmpty) {
      _showSnackBar('Error: Please save your Instance ID and Access Token first.');
      return;
    }

    if (!isRetry) {
      setState(() {
        _statusMessage = 'Fetching current profile name... 📡';
      });
    } else {
      setState(() {
        _statusMessage = 'Retrying fetch profile with default credentials... 🔄';
      });
    }

    final uri = Uri.parse('https://wawp.net/wp-json/awp/v1/profile').replace(queryParameters: {
      'instance_id': _storedInstanceId,
      'access_token': _storedAccessToken,
    });

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        // SUCCESS
        final body = response.body;
        final decodedJson = jsonDecode(body);
        final fetchedName = decodedJson['profile']?['name'] ?? 'Name not found';

        setState(() {
          _currentName = fetchedName;
          _nameController.text = fetchedName;
          final displayBody = body.length > 100 ? '${body.substring(0, 100)}...' : body;
          _statusMessage = 'Success! Profile loaded. Fetched Name: $_currentName. API Response: $displayBody';
        });
        _showSnackBar('Current profile name loaded successfully! 🎉');
      } else if (!isRetry) {
        // FAILURE - ATTEMPT RETRY
        await _handleApiFailureAndRetry(() => _loadCurrentProfile, 'Profile load failed: ${response.reasonPhrase}');
      } else {
        // FAILURE - AFTER RETRY
        setState(() {
          _statusMessage = 'Error (${response.statusCode}): ${response.reasonPhrase}. Profile load failed even with default credentials.';
          _currentName = 'Load Failed';
        });
        _showSnackBar('Failed to load profile (Retry failed): ${response.reasonPhrase} ❌');
      }
    } catch (e) {
      // NETWORK ERROR
      setState(() {
        _statusMessage = 'Network Error: Failed to reach the server. Exception: $e';
        _currentName = 'Load Failed';
      });
      _showSnackBar('A network error occurred. Check your connection. 🌐');
    }
  }

  /// Sends a GET request to check the presence of a specific WhatsApp user ID. (No retry logic needed here)
  Future<void> _checkUserPresence() async {
    const targetJid = '255779480621@c.us';

    if (_storedInstanceId.isEmpty || _storedAccessToken.isEmpty) {
      _showSnackBar('Error: Please save your Instance ID and Access Token first.');
      return;
    }

    setState(() {
      _statusMessage = 'Checking presence for $targetJid... 🔍';
      _presenceStatus = 'Checking...';
    });

    final uri = Uri.parse('https://wawp.net/wp-json/awp/v1/presence/$targetJid').replace(queryParameters: {
      'instance_id': _storedInstanceId,
      'access_token': _storedAccessToken,
    });

    try {
      final request = http.Request('GET', uri);
      final response = await request.send();

      final responseBody = await response.stream.bytesToString();
      final statusCode = response.statusCode;
      final reasonPhrase = response.reasonPhrase;

      if (statusCode == 200) {
        String statusResult = 'Offline (No Data)';
        try {
          final decodedJson = jsonDecode(responseBody);
          final presences = decodedJson['presences'] as List?;

          if (presences != null && presences.isNotEmpty) {
            statusResult = presences.first['status'] ?? 'Online (Unknown Status)';
          } else {
            statusResult = 'Offline (No Presence Data)';
          }

        } catch (_) {
          statusResult = 'Success (Raw Response)';
        }

        setState(() {
          _presenceStatus = statusResult;
          final displayBody = responseBody.length > 100 ? '${responseBody.substring(0, 100)}...' : responseBody;
          _statusMessage = 'Presence Check Success! Status: $statusResult. API Response: $displayBody';
        });
        _showSnackBar('Presence check successful! 🟢');
      } else {
        setState(() {
          _presenceStatus = 'Failed ($statusCode)';
          _statusMessage = 'Presence Check Error ($statusCode): $reasonPhrase';
        });
        _showSnackBar('Failed to check presence: $reasonPhrase 🔴');
      }
    } catch (e) {
      setState(() {
        _presenceStatus = 'Network Error';
        _statusMessage = 'Network Error: Failed to reach the server. Exception: $e';
      });
      _showSnackBar('A network error occurred. Check your connection. ⚠️');
    }
  }

// -----------------------------------------------------------------
//                          API CALLS (PUT/POST/SMS)
// -----------------------------------------------------------------

  /// Sends a PUT request to update the business name using stored credentials.
  /// Includes retry logic on failure.
  Future<void> _setBusinessName({bool isRetry = false}) async {
    final businessName = _nameController.text.trim();

    if (_storedInstanceId.isEmpty || _storedAccessToken.isEmpty) {
      _showSnackBar('Error: Please save your Instance ID and Access Token first.');
      return;
    }

    if (businessName.isEmpty) {
      _showSnackBar('Please enter a new business name.');
      return;
    }

    if (!isRetry) {
      setState(() {
        _statusMessage = 'Updating business name for "$businessName"... 📤';
      });
    } else {
      setState(() {
        _statusMessage = 'Retrying name update with default credentials... 🔄';
      });
    }


    final uri = Uri.parse('https://wawp.net/wp-json/awp/v1/profile/name').replace(queryParameters: {
      'instance_id': _storedInstanceId,
      'access_token': _storedAccessToken,
      'name': businessName,
    });

    try {
      final request = http.Request('PUT', uri);
      final streamedResponse = await request.send();

      final responseBody = await streamedResponse.stream.bytesToString();
      final statusCode = streamedResponse.statusCode;
      final reasonPhrase = streamedResponse.reasonPhrase;

      if (statusCode == 200) {
        // SUCCESS
        setState(() {
          final displayBody = responseBody.length > 100 ? '${responseBody.substring(0, 100)}...' : responseBody;
          _statusMessage = 'Success! Name updated. API Response: $displayBody';
        });
        _showSnackBar('Business name updated successfully! ✏️');
        _loadCurrentProfile(); // Refresh current name
      } else if (!isRetry) {
        // FAILURE - ATTEMPT RETRY
        await _handleApiFailureAndRetry(() => _setBusinessName, 'Name update failed: $reasonPhrase');
      } else {
        // FAILURE - AFTER RETRY
        setState(() {
          _statusMessage = 'Error ($statusCode): $reasonPhrase\nResponse Body: $responseBody. Update failed even with default credentials.';
        });
        _showSnackBar('Failed to update name (Retry failed): $reasonPhrase ❌');
      }
    } catch (e) {
      // NETWORK ERROR
      setState(() {
        _statusMessage = 'Network Error: Failed to reach the server. Exception: $e';
      });
      _showSnackBar('A network error occurred. Check your connection. ⚠️');
    }
  }

  /// Placeholder for the SMS sending function that would use the retry logic.
  Future<void> _sendSmsPlaceholder({bool isRetry = false}) async {
    // This function simulates an SMS sending failure and the subsequent retry.

    if (_storedInstanceId.isEmpty || _storedAccessToken.isEmpty) {
      _showSnackBar('Error: Please save your Instance ID and Access Token first.');
      return;
    }

    if (!isRetry) {
      setState(() {
        _statusMessage = 'Sending SMS (Simulating failure)... ✉️';
      });
    } else {
      setState(() {
        _statusMessage = 'SMS Retry Attempt with default keys... 🔄';
      });
    }


    // --- SIMULATE API FAILURE ---
    // Change 'true' to 'false' to simulate a success on the first attempt
    bool initialAttemptFailed = true;

    // Simulate success on retry attempt to demonstrate failover
    bool retryAttemptSuccess = isRetry;

    if (initialAttemptFailed && !retryAttemptSuccess && !isRetry) {
      // Only fail on the first attempt
      await _handleApiFailureAndRetry(() => _sendSmsPlaceholder, 'Simulated SMS API Failure (401 Unauthorized)');
    } else {
      // Success either on the first try (if !initialAttemptFailed) or on the retry
      _showSnackBar(isRetry ? 'SMS sent successfully on retry! ✅' : 'SMS sent successfully! (Simulated) ✅');
      setState(() {
        _statusMessage = isRetry ? 'SMS sent successfully using default keys.' : 'SMS sent successfully!';
      });
    }
  }


// -----------------------------------------------------------------
//                             UTILITY
// -----------------------------------------------------------------

  /// Shows a persistent Snackbar at the bottom of the screen.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

// -----------------------------------------------------------------
//                                UI
// -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Configuration'),
        backgroundColor: Colors.teal,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Credential Section ---
            const Text(
              'API Credentials',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instanceController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Instance ID (Hidden if Default)',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                prefixIcon: Icon(Icons.qr_code, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Access Token (Hidden if Default)',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                prefixIcon: Icon(Icons.vpn_key, color: Colors.teal),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Credentials'),
              onPressed: _saveWhatsAppSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const Divider(height: 40, thickness: 1.5, color: Colors.grey),

            // --- Profile Update Section ---
            const Text(
              'Profile and Name Update',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 12),

            // Load/Display Current Name Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current Name: $_currentName',
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Load Current Name'),
                  onPressed: _loadCurrentProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Set Business Name Field & Button
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'New Business Name',
                hintText: 'e.g., E-PHAMARCY SOFTWARE',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                prefixIcon: Icon(Icons.business, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Set Business Name (PUT)'),
              onPressed: _setBusinessName,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            // --- SMS Placeholder Button ---
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.sms),
              label: const Text('Send SMS (Simulate Failure/Retry)'),
              onPressed: _sendSmsPlaceholder, // Use the new placeholder
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const Divider(height: 40, thickness: 1.5, color: Colors.grey),

            // --- Presence Check Section ---
            const Text(
              'User Presence Check',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Target Status: $_presenceStatus',
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.purple),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.online_prediction, size: 18),
                  label: const Text('Check Presence'),
                  onPressed: _checkUserPresence,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- Status Display ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    SelectableText(_statusMessage, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}