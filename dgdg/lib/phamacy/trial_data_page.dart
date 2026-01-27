import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Mock login and payment screens
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Login Screen')));
}

class PaymentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Payment Screen')));
}

// Global navigator key for navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class TrialDataPage extends StatefulWidget {
  @override
  _TrialDataPageState createState() => _TrialDataPageState();
}

class _TrialDataPageState extends State<TrialDataPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _initializeTrialPeriod(); // Check trial and route accordingly
    sendEmailWithIp(); // Email IP/device info
  }

  Future<void> _initializeTrialPeriod() async {
    try {
      DateTime trialStart = await _dbHelper.getTrialStartDate();
      int daysUsed = DateTime.now().difference(trialStart).inDays;

      if (daysUsed <= 30) {
        _navigateTo(LoginScreen());
      } else {
        bool expired = await isPaymentExpired();
        _navigateTo(expired ? PaymentScreen() : LoginScreen());
      }
    } catch (e) {
      if (e.toString().contains("No trial start date found")) {
        await _dbHelper.insertTrialStartDate(DateTime.now());
        _navigateTo(LoginScreen());
      } else {
        print('Trial check error: $e');
      }
    }
  }

  void _navigateTo(Widget screen) {
    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Initializing Trial...')),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class DatabaseHelper {
  static final _dbName = 'ePharmacy.db';
  static final _dbVersion = 1;
  static final _trialTable = 'trial';
  static final columnTrialStartDate = 'trial_start_date';
  Database? _db;

  Future<Database> get db async {
    if (_db == null) _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = Directory('C:/Users/Public/payzz');
    if (!(await dir.exists())) await dir.create(recursive: true);
    return await openDatabase(join(dir.path, _dbName),
        version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_trialTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTrialStartDate TEXT NOT NULL
      )
    ''');
  }

  Future<DateTime> getTrialStartDate() async {
    final result = await (await db).query(_trialTable, limit: 1);
    if (result.isNotEmpty) {
      return DateTime.parse(result.first[columnTrialStartDate] as String);
    }
    throw Exception("No trial start date found");
  }

  Future<void> insertTrialStartDate(DateTime date) async {
    await (await db).insert(_trialTable, {
      columnTrialStartDate: date.toIso8601String(),
    });
  }
}

// Dummy payment expiration checker using JSON
Future<bool> isPaymentExpired() async {
  final file = File('C:/Users/Public/payzz/payment.json');
  if (await file.exists()) {
    final content = await file.readAsString();
    return content.contains('"status": "expired"');
  }
  return true; // Assume expired if file is missing
}

// Dummy IP sender (replace with real logic if needed)
void sendEmailWithIp() {
  print("Sending IP and device info via email...");
}

// Entry point
void main() {
  runApp(MaterialApp(
    navigatorKey: navigatorKey,
    home: TrialDataPage(),
  ));
}
