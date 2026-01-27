import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final _dbName = 'ePharmacy.db';
  static final _dbVersion = 1;

  static final _trialTable = 'trial';
  static final _paymentsTable = 'payments';

  static final columnTrialStartDate = 'trial_start_date';
  static final columnStatus = 'status';
  static final columnPaymentMethod = 'payment_method';
  static final columnAmount = 'amount';
  static final columnConfirmationCode = 'confirmation_code';
  static final columnOrderTrackingId = 'order_tracking_id';
  static final columnMerchantReference = 'merchant_reference';
  static final columnPaymentTime = 'payment_time';

  Database? _db;

  Future<Database> get db async {
    if (_db == null) {
      _db = await _initDb();
    }
    return _db!;
  }

  Future<Database> _initDb() async {
    final publicDir = Directory('C:/Users/Public/payzz');
    if (!(await publicDir.exists())) {
      await publicDir.create(recursive: true);
    }

    final path = join(publicDir.path, _dbName);
    return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_trialTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTrialStartDate TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_paymentsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnStatus TEXT NOT NULL,
        $columnPaymentMethod TEXT NOT NULL,
        $columnAmount TEXT NOT NULL,
        $columnConfirmationCode TEXT NOT NULL,
        $columnOrderTrackingId TEXT NOT NULL,
        $columnMerchantReference TEXT NOT NULL,
        $columnPaymentTime TEXT NOT NULL
      )
    ''');
  }

  Future<DateTime> getTrialStartDate() async {
    final dbClient = await db;
    final result = await dbClient.query(_trialTable, limit: 1);

    if (result.isNotEmpty) {
      return DateTime.parse(result.first[columnTrialStartDate] as String);
    } else {
      throw Exception("No trial start date found");
    }
  }

  Future<void> insertTrialStartDate(DateTime date) async {
    final dbClient = await db;
    await dbClient.insert(_trialTable, {
      columnTrialStartDate: date.toIso8601String(),
    });
  }
}
