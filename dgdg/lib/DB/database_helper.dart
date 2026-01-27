import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchronized/synchronized.dart';
import 'package:sqflite_common/sqflite.dart';
import 'dart:convert';

import '../API/payment_conmfemetion.dart';
import '../login.dart';
import '../main.dart';
import '../phamacy/trial_data_page.dart' hide PaymentScreen;

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static const String table = 'businesses';
  static const String columnId = 'id';
  Database? _database;

  Future<Database> get database async => _database ??= await _initDatabase();

  // ---------------------- _initDatabase ----------------------
  Future<Database> _initDatabase() async {
    String dbPath;

    if (Platform.isWindows) {
      // Initialize FFI for Windows
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final directoryPath = r'C:\Users\Public\epharmacy';
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
        print("Directory created: $directoryPath");
      }
      dbPath = join(directoryPath, 'epharmacy.db');
    }
    else if (Platform.isAndroid || Platform.isIOS) {
      final defaultDbPath = await getDatabasesPath();
      final directoryPath = join(defaultDbPath, 'epharmacy');
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      dbPath = join(directoryPath, 'epharmacy.db');
    }
    else {
      throw UnsupportedError('Unsupported platform');
    }

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Migration logic for version 2
          // e.g., await db.execute('ALTER TABLE ...');
        }
      },
    );
  }

  // ---------------------- _onCreate ----------------------
  Future _onCreate(Database db, int version) async {
    print("Creating new database with version $version");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        role TEXT NOT NULL,
        professional TEXT,
        password TEXT NOT NULL,
        businessName TEXT,
        reset_code TEXT,
        reset_code_expiry INTEGER,
        synced INTEGER DEFAULT 0,
        profile_picture TEXT,
        is_disabled INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ncd_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hospital TEXT NOT NULL,
        indicator TEXT NOT NULL,
        age_group TEXT NOT NULL,
        gender TEXT NOT NULL,
        value INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS other_product_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        company TEXT,
        total_quantity INTEGER,
        remaining_quantity INTEGER,
        buy_price REAL,
        selling_price REAL,
        batch_number TEXT,
        manufacture_date TEXT,
        expiry_date TEXT,
        added_by TEXT,
        discount REAL,
        unit TEXT,
        business_name TEXT,
        date_added TEXT,
        action TEXT,
        last_updated TEXT NULL
      )
    ''');



      // Upgrade to version 2
        await db.execute('''
        CREATE TABLE IF NOT EXISTS other_product_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          company TEXT,
          total_quantity INTEGER,
          remaining_quantity INTEGER,
          buy_price REAL,
          selling_price REAL,
          batch_number TEXT,
          manufacture_date TEXT,
          expiry_date TEXT,
          added_by TEXT,
          discount REAL,
          unit TEXT,
          business_name TEXT,
          date_added TEXT,
          action TEXT,
          last_updated TEXT NULL
        )
      ''');

        // You can also add new columns here with ALTER TABLE if needed


      // Future upgrades:
      // if (oldVersion < 3) { ... }




      await db.execute('''
  CREATE TABLE IF NOT EXISTS company (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    businessName TEXT,
    business_logo TEXT
  );
''');

      // Create table for tracking installation date and subscription status
      await db.execute('''
          CREATE TABLE user_subscription(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            installation_date TEXT,
            businessName TEXT,
            subscription_status TEXT
          );
        ''');
      await db.execute('''
  CREATE TABLE IF NOT EXISTS medicines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    company TEXT NOT NULL,
    total_quantity INTEGER NOT NULL,
    remaining_quantity INTEGER NOT NULL,
    buy REAL NOT NULL,
    price REAL NOT NULL,
    batchNumber TEXT NOT NULL,
    manufacture_date TEXT NOT NULL,
    expiry_date TEXT NOT NULL,
    added_by TEXT NOT NULL,
    discount REAL,
    added_time TEXT,
    unit TEXT,
    businessName TEXT,
    synced INTEGER DEFAULT 0
  );
''');
      await db.execute('''
    CREATE TABLE indicator_data (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      indicator TEXT NOT NULL,
      v0_17_me INTEGER,
      v0_17_fe INTEGER,
      total_0_17 INTEGER,
      v18_29_me INTEGER,
      v18_29_fe INTEGER,
      total_18_29 INTEGER,
      v30_69_me INTEGER,
      v30_69_fe INTEGER,
      total_30_69 INTEGER,
      v70_plus_me INTEGER,
      v70_plus_fe INTEGER,
      total_70_plus INTEGER,
      all_total INTEGER
    )
  ''');

      await db.execute('''
  CREATE TABLE IF NOT EXISTS salaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    phone TEXT,
    amount REAL,
    pay_date TEXT,
    synced INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
''');


      await db.execute('''      
    CREATE TABLE normal_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        category TEXT NOT NULL,          -- Example: 'Food', 'Electricity', 'Water', 'Other'
        description TEXT,                -- Used only when category = 'Other'
        amount REAL NOT NULL,
        usage_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        added_by TEXT,                   -- Optional: name or ID of staff
        FOREIGN KEY (user_id) REFERENCES users(id)
    );

    ''');
      await db.execute('''
  CREATE TABLE IF NOT EXISTS invoices (
    invoice_id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    price REAL NOT NULL,
    total REAL NOT NULL,
    unit TEXT NOT NULL,
    customer_name TEXT,
    added_time TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );
''');


// Method to insert invoice into the database
      Future<void> insertInvoice(String itemName, int quantity, double price, double total, String unit) async {
        final db = await database;

        // Insert invoice data into the invoices table
        await db.insert(
          'invoices',
          {
            'item_name': itemName,
            'quantity': quantity,
            'price': price,
            'total': total,
            'unit': unit,
            'added_time': DateTime.now().toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,  // Replace if a duplicate entry exists
        );

        print('Invoice saved successfully.');
      }

      await db.execute('''
  CREATE TABLE IF NOT EXISTS store (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    company TEXT,
    quantity INTEGER,
    buy_price REAL,       -- ✅ important
    price REAL,
    unit TEXT,
    batchNumber TEXT,
    manufacture_date TEXT,
    expiry_date TEXT,
    added_by TEXT,
    business_name TEXT,
    added_time TEXT
  );
''');

      await db.execute('''
  CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE NOT NULL,
    amount REAL NOT NULL,
    payment_status TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    payment_method TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    sale_id INTEGER,
    sale_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sale_id) REFERENCES sales(id)
  )
''');

      await db.execute('''
  CREATE TABLE IF NOT EXISTS sales (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    medicine_name TEXT,
    total_quantity INTEGER,
    remaining_quantity INTEGER,
    total_price REAL,
    receipt_number TEXT,
    payment_method TEXT,
    confirmed_time TEXT,
    user_id INTEGER,          -- The user who made the sale
    confirmed_by INTEGER,     -- The user who confirmed the sale
    user_role TEXT,           -- Role of the user
    staff_id INTEGER,         -- Staff ID handling the sale
    unit TEXT,                -- Field for storing unit
    synced INTEGER DEFAULT 0,
    source TEXT,
    business_name TEXT,
    partial_payment_date TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    full_name TEXT,
    paid_time TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (confirmed_by) REFERENCES users(id)
  );
''');

    await db.execute('''
  CREATE TABLE IF NOT EXISTS cart_sync (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    medicine_name TEXT, -- This stores the target table (sales/To_lend)
    action_type TEXT,   -- INSERT_SALE, UPDATE_STOCK, etc.
    quantity INTEGER,
    status TEXT DEFAULT 'pending',
    payload TEXT,       -- THE MISSING COLUMN
    created_at TEXT DEFAULT (datetime('now', 'localtime'))
  )
''');
    // Add this inside your DatabaseHelper onCreate method


      await db.execute('''
  CREATE TABLE IF NOT EXISTS sale_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sale_id INTEGER,
    medicine_id INTEGER,
    medicine_name TEXT,
    quantity INTEGER DEFAULT 1,
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    remaining_quantity INTEGER,
    price REAL,
    unit TEXT,
    receipt_number TEXT UNIQUE,
    payment_method TEXT,
    confirmed_time TEXT,
    date_added TEXT,         -- ✅ Add this
    added_by INTEGER,        -- ✅ Add this
    source TEXT,
    business_name TEXT,
    FOREIGN KEY (sale_id) REFERENCES sales(id),
    FOREIGN KEY (added_by) REFERENCES users(id),
    FOREIGN KEY (medicine_id) REFERENCES medicines(id)
  );
''');

      await db.execute('''
  CREATE TABLE IF NOT EXISTS cart (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    medicine_id INTEGER,
    medicine_name TEXT NOT NULL,
    company TEXT NOT NULL,
    price REAL,
    date_added TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    quantity INTEGER,
    unit TEXT NOT NULL,
    source TEXT,
    business_name TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (medicine_id) REFERENCES medicines(id)
  );
''');

      await db.execute('''      
      CREATE TABLE pending_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        sale_id INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (sale_id) REFERENCES sales(id)
      )
    ''');

      await db.execute('''      
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT NOT NULL,
        timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');


      await db.execute('''      
     CREATE TABLE migration_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
  medicine_id INTEGER,
  quantity_migrated INTEGER,
  discount REAL,
  migration_date TEXT,
  status TEXT,
  business_name TEXT,
  added_by TEXT,
  medicine_name TEXT,
  manufacture_date TEXT,
  expiry_date TEXT,
  batchNumber TEXT,
  company TEXT,
  quantity INTEGER,
  price REAL,
  buy REAL,
  unit TEXT
);

    ''');

      await db.execute('''
 CREATE TABLE medical_logs (
   id INTEGER PRIMARY KEY AUTOINCREMENT,
  medicine_name TEXT,
  company TEXT,
  total_quantity INTEGER,           
  remaining_quantity REAL,         
  buy_price REAL,
  selling_price REAL,
  batch_number TEXT,
  manufacture_date TEXT,
  expiry_date TEXT,
  added_by TEXT,
  discount REAL,
  unit TEXT,
  business_name TEXT,
  date_added TEXT,
  action TEXT,
  synced INTEGER DEFAULT 0
);


''');




      await db.execute('''
  CREATE TABLE IF NOT EXISTS deleted_medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        company TEXT NOT NULL,
        total_quantity INTEGER NOT NULL,
        remaining_quantity INTEGER NOT NULL,
        buy REAL NOT NULL,
        price REAL NOT NULL,
        batchNumber TEXT NOT NULL,
        manufacture_date TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        added_by INTEGER NOT NULL,
        discount REAL NOT NULL,
        date_added TEXT NOT NULL,
        unit TEXT NOT NULL,
        business_name TEXT NOT NULL,
        deleted_date TEXT
    );
''');
      await db.execute('''
  CREATE TABLE IF NOT EXISTS businesses(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    business_name TEXT,
    email TEXT,
    phone TEXT,
    logo TEXT,
    location TEXT,
    address TEXT,
    whatsapp TEXT,
    lipa_number TEXT
  )
''');
      await db.execute('''
  CREATE TABLE IF NOT EXISTS user_permissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    business_name TEXT NOT NULL,
    permission TEXT NOT NULL,
    synced INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
''');


      await db.execute('''
    CREATE TABLE IF NOT EXISTS diary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      business_name TEXT NOT NULL,
      user_name TEXT NOT NULL,
      activity_title TEXT NOT NULL,
      activity_description TEXT NOT NULL,
      activity_date TEXT NOT NULL,
      synced INTEGER DEFAULT 0
    );
  ''');

      await db.execute('''
  CREATE TABLE IF NOT EXISTS upcoming_event (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    business_name TEXT,
    user_name TEXT,
    event_title TEXT NOT NULL,
    event_date TEXT NOT NULL,
    created_at TEXT NOT NULL,
    last_notified TEXT,
    synced INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
''');


      await db.execute('''
  CREATE TABLE IF NOT EXISTS To_lend (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    medicine_name TEXT,
    total_quantity INTEGER,
    remaining_quantity INTEGER,
    total_price REAL,
    receipt_number TEXT,
    payment_method TEXT,
    confirmed_time TEXT,
    user_id INTEGER,
    confirmed_by TEXT,
    user_role TEXT,
    staff_id INTEGER,
    unit TEXT,
    business_name TEXT,           -- ✅ Added this line
    source TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
''');



      await db.execute('''
  CREATE TABLE IF NOT EXISTS other_product (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    company TEXT NOT NULL,
    manufacture_date TEXT,
    expiry_date TEXT,
    total_quantity INTEGER NOT NULL,
    remaining_quantity REAL NOT NULL,
    buy_price REAL NOT NULL,
    selling_price REAL NOT NULL,
    batch_number TEXT NOT NULL,
    added_by TEXT NOT NULL,
    discount REAL,
    unit TEXT,
    business_name TEXT,
    date_added TEXT,
    product_type TEXT,
    product_category TEXT,
    last_updated TEXT NULL,
    synced INTEGER DEFAULT 0
  );
''');


      await db.execute('''
  CREATE TABLE IF NOT EXISTS product_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_name TEXT NOT NULL,
    company TEXT NOT NULL,
    manufacture_date TEXT,
    expiry_date TEXT,
    total_quantity INTEGER NOT NULL,
    remaining_quantity REAL NOT NULL,
    buy_price REAL NOT NULL,
    selling_price REAL NOT NULL,
    batch_number TEXT NOT NULL,
    added_by TEXT NOT NULL,
    discount REAL,
    unit TEXT,
    business_name TEXT,
    date_added TEXT,
    product_type TEXT,
    product_category TEXT,
    action TEXT,
    synced INTEGER DEFAULT 0
  );
''');

      await db.execute('''
  CREATE TABLE IF NOT EXISTS To_lent_payedLogs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_name TEXT,
  customer_phone TEXT,
  customer_email TEXT,
  medicine_name TEXT,
  remaining_quantity INTEGER,
  total_quantity INTEGER,           -- Added missing column
  total_price REAL,
  receipt_number TEXT,
  payment_method TEXT,
  confirmed_time TEXT,
  user_id INTEGER,                  -- ID of the user who made the sale
  confirmed_by TEXT,                -- Name or ID of user confirming
  user_role TEXT,                   -- Role of user
  staff_id INTEGER,                 -- Staff ID
  unit TEXT,                        -- e.g., box, tablet
  synced INTEGER DEFAULT 0,
  business_name TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  partial_payment_date TEXT,
  source TEXT,
  full_name TEXT,
  paid_time TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

''');


      await db.execute('''
    CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT,
        kg TEXT,
        business_name TEXT,
        business_email TEXT,
        business_phone TEXT,
        business_location TEXT,
        business_logo_path TEXT,
        address TEXT,
        whatsapp TEXT,
        lipa_number TEXT,
        created_at TEXT  -- Column to store the time the product is created
    );
''');
      await db.execute('''      
      CREATE TABLE sales_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER,
        report TEXT NOT NULL,
        generated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sale_id) REFERENCES sales(id)
      )
    ''');
      await db.execute('''
      CREATE TABLE companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT NOT NULL
      )
    ''');
      await db.execute('''
      CREATE TABLE payment_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        status TEXT NOT NULL,
        message TEXT,
        payment_method TEXT,
        amount REAL NOT NULL,
        confirmation_code TEXT,
        order_tracking_id TEXT,
        merchant_reference TEXT,
        currency TEXT DEFAULT 'USD',
        payment_date TEXT,
        next_payment_date TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        business_name TEXT,
        first_name TEXT,
        last_name TEXT
      )
    ''');

      // ✅ Insert default payment transaction
      final now = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      await db.insert('payment_transactions', {
        'status': 'Completed',
        'message': 'Payed',
        'payment_method': 'Tigo',
        'amount': 10000.0,
        'confirmation_code': '959303',
        'order_tracking_id': '959303',
        'merchant_reference': '959303',
        'currency': 'Tsh',
        'payment_date': formatter.format(now),
        'next_payment_date': formatter.format(now.add(const Duration(days: 30))),
        'synced': 1,
        'created_at': formatter.format(now),
        'business_name': '',
        'first_name': '',
        'last_name': ''
      });


      Future<void> addMedicine(
          String name,
          String company,
          int totalQuantity,  // Total quantity (int)
          int remainingQuantity,  // Remaining quantity (int)
          double buy,  // Buy price (double)
          double price,  // Selling price (double)
          String batchNumber,
          String manufactureDate,  // Manufacture date (String)
          String expiryDate,  // Expiry date (String)
          String addedBy,
          double discount,  // Discount (double)
          String dateAdded,
          String unit,
          String businessName,
          ) async {
        final db = await instance.database;
        await db.insert('medicines', {
          'name': name,
          'company': company,
          'total_quantity': totalQuantity,
          'remaining_quantity': remainingQuantity,
          'buy_price': buy.toDouble(),
          'price': price.toDouble(),
          'batch_number': batchNumber,
          'manufacture_date': manufactureDate,
          'expiry_date': expiryDate,
          'added_by': addedBy,
          'discount': discount.toDouble(),
          'date_added': dateAdded,
          'unit': unit,
          'business_name': businessName,

        });
      }
      Future<bool> businessExists(String businessName) async {
        final db = await database;
        final result = await db.query(
          'business_details',  // replace with your actual business table name
          where: 'business_name = ?',
          whereArgs: [businessName],
          limit: 1,
        );
        return result.isNotEmpty;
      }
      Future<List<String>> getBusinessNames() async {
        final db = await database;
        final results = await db.query(
          'businesses',
          columns: ['business_name'],
        );
        return results.map((row) => row['business_name'].toString()).toList();
      }

// Inside your DatabaseHelper class
      Future<List<Map<String, dynamic>>> fetchSalesByDate(String? date) async {
        final db = await database;
        String query = "SELECT * FROM sales";
        List<String> where = [];
        List<dynamic> args = [];

        if (date != null) {
          where.add("DATE(sale_date) = ?");
          args.add(date);
        }

        if (where.isNotEmpty) {
          query += " WHERE " + where.join(" AND ");
        }

        return await db.rawQuery(query, args);
      }

// Inside your DatabaseHelper class
      Future<List<Map<String, dynamic>>> queryAllMedicines() async {
        final db = await database;
        return await db.query('medicines');
      }
      Future<void> updateRemainingQuantity(int medicineId, int quantityUsed) async {
        final db = await instance.database;
        await db.rawUpdate(
          'UPDATE medicines SET remaining_quantity = remaining_quantity - ? WHERE id = ?',
          [quantityUsed, medicineId],
        );
      }

      Future<List<Map<String, dynamic>>> queryUsageByDate(DateTime? start, DateTime? end) async {
        final db = await database;
        String startStr = start != null ? start.toIso8601String() : '';
        String endStr = end != null ? end.toIso8601String() : '';

        return await db.query(
          'normal_usage',
          where: start != null && end != null
              ? 'usage_date BETWEEN ? AND ?'
              : null,
          whereArgs: start != null && end != null ? [startStr, endStr] : null,
        );
      }


      // Inside your initialization logic
      String hashedPassword = sha256.convert(utf8.encode("admin123")).toString();

// Insert locally (SQLite)
      await db.insert('users', {
        'full_name': 'Admin',
        'email': 'admin@example.com',
        'phone': '0000000000',
        'role': 'admin',
        'professional': 'IT',
        'password': hashedPassword,
        'businessName': 'itc',
        'is_disabled': '0'
      });

// Insert remotely (PHP server)
      try {
        final response = await http.post(
          Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/insert_user.php'),
          body: {
            'full_name': 'Admin',
            'email': 'admin@example.com',
            'phone': '0000000000',
            'role': 'admin',
            'professional': 'IT',
            'password': hashedPassword,
            'businessName': 'itc',
            'is_disabled': '0',
          },
        );

        if (response.statusCode == 200 && response.body.contains('success')) {
          print('User inserted to remote server.');
        } else {
          print('Remote insert failed: ${response.body}');
        }
      } catch (e) {
        print('Error sending data to server: $e');
      }

    // Add more CREATE TABLE statements here for all other tables
  }

  // ---------------------- _onUpgrade ----------------------

  Future<void> addToStore({
    required String name,
    required String company,
    required int quantity,
    required double price,
    required double buy,
    required double unit,
    required String manufactureDate,
    required String expiryDate,
    required String batchNumber,
    required String addedBy,
    required String businessName,
  }) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert('store', {
      'name': name,
      'company': company,
      'quantity': quantity,
      'price': price,
      'buy': buy,
      'unit': unit,
      'manufacture_date': manufactureDate,
      'expiry_date': expiryDate,
      'batchNumber': batchNumber,
      'added_by': addedBy,
      'business_name': businessName,
      'added_time': DateTime.now().toIso8601String(),
    });

    print('Medicine added to store.');
  }

  Future<int> updateMedicineInStore({
    required int id, // Unique ID of the medicine
    required String name,
    required String company,
    required int quantity,
    required double buy_price,
    required double price,
    required String unit,
    required String batchNumber,
    required String manufactureDate,
    required String expiryDate,
    required String updatedBy,
    required String businessName,
    required String updatedAt,
  }) async {
    try {
      final db = await database;

      return await db.update(
        'tbl_medicine_store', // Table name
        {
          'name': name,
          'company': company,
          'quantity': quantity,
          'buy_price': buy_price,
          'price': price,
          'unit': unit,
          'batch_number': batchNumber,
          'manufacture_date': manufactureDate,
          'expiry_date': expiryDate,
          'updated_by': updatedBy,
          'business_name': businessName,
          'updated_at': updatedAt,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error updating medicine record: $e');
      return 0; // Return 0 if update fails
    }
  }

  // Method to get all deleted medicines
  Future<List<Map<String, dynamic>>> getAllDeletedMedicines() async {
    final db = await instance.database;

    // Fetch all data from the deleted_medicines table
    final List<Map<String, dynamic>> result = await db.query('deleted_medicines');
    return result;
  }
  Future<List<Map<String, dynamic>>> getAllMedicalLogs() async {
    final db = await database;
    return await db.query(
      'medical_logs',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'date_added DESC',
    );
  }
// Fetch all unsynced sales (synced = 0), optionally filtered by date
  Future<List<Map<String, dynamic>>> fetchUnsyncedSales({String? date}) async {
    final db = await database;

    String query = "SELECT * FROM sales WHERE synced = 0";
    List<dynamic> args = [];

    if (date != null) {
      query += " AND DATE(sale_date) = ?";
      args.add(date);
    }

    return await db.rawQuery(query, args);
  }

// Update sync status of a sale record by id
  Future<int> updateSaleSyncStatus(int saleId, {required int synced}) async {
    final db = await database;
    return await db.update(
      'sales',
      {'synced': synced},
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }

  /// Fetch only UNSYNCED medical logs (where synced = 0)
  Future<List<Map<String, dynamic>>> getUnsyncedLogs() async {
    final db = await database;
    return await db.query(
      'medical_logs',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'date_added DESC',
    );
  }

  Future<int> updateMedicalLogSyncedFlag(int id, int flag) async {
    final db = await database;
    return await db.update(
      'medical_logs',
      {'synced': flag},
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  Future<List<Map<String, dynamic>>> fetchAllPaymentTransactions() async {
    final db = await instance.database;

    final List<Map<String, dynamic>> results = await db.query(
      'payment_transactions',
      orderBy: 'created_at DESC',
    );

    return results;
  }

  Future<Map<String, dynamic>?> fetchLatestPaymentTransaction() async {
    final db = await database;

    final List<Map<String, dynamic>> result = await db.query(
      'payment_table', // Replace with your actual table name
      orderBy: 'payment_date DESC', // Or 'id DESC' if you store them chronologically
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    } else {
      return null;
    }
  }



  Future<Map<String, dynamic>?> fetchPaymentById(int id) async {
    final db = await instance.database;

    final List<Map<String, dynamic>> results = await db.query(
      'payment_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }
// Check if a value exists in a specific column of the companies table
  Future<bool> isCompanyFieldExists(String field, String value) async {
    final db = await database;
    final result = await db.query(
      'companies',
      where: '$field = ?',
      whereArgs: [value],
    );
    return result.isNotEmpty;
  }

  Future<void> insertTransaction(PaymentTransaction transaction) async {
    final db = await instance.database;
    await db.insert(
      'payment_transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertCompany(Map<String, dynamic> company) async {
    final db = await database;
    return await db.insert('companies', company);
  }

  Future<int> insertSalary(Map<String, dynamic> salaryData) async {
    final db = await database;
    return await db.insert('salaries', salaryData);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query(
      'users',
      columns: [
        'id',
        'full_name',
        'phone',
        'email',
        'role',
        'professional',
        'businessName',
        'is_disabled'
      ],
    );
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    return await db.rawQuery('SELECT * FROM payment_transactions');
  }


  // 5. Query total income with required start and end date
  Future<List<Map<String, dynamic>>> queryTotalIncome(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery(
      'SELECT SUM(total_price) AS total_income FROM sales WHERE confirmed_time BETWEEN ? AND ?',
      [startDate, endDate],
    );
  }

// 6. Query total sales with required start and end date
  Future<List<Map<String, dynamic>>> queryTotalSales(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery(
      'SELECT SUM(total_price) AS total_sales FROM sales WHERE confirmed_time BETWEEN ? AND ?',
      [startDate, endDate],
    );
  }

// 7. Query total expenses with required start and end date
  Future<List<Map<String, dynamic>>> queryTotalExpenses(String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT SUM(total) AS total_expenses FROM (
      SELECT amount AS total FROM normal_usage WHERE usage_date BETWEEN ? AND ?
      UNION ALL
      SELECT amount AS total FROM salaries WHERE pay_date BETWEEN ? AND ?
    )
  ''', [startDate, endDate, startDate, endDate]);
  }


// 8. Query cash in hand for a specific date (you can modify to filter by date if needed)
  Future<List<Map<String, dynamic>>> queryCashInHand(String paymentMethod) async {
    final db = await database;
    return await db.rawQuery(
      'SELECT SUM(total_price) AS cash_in_hand FROM sales WHERE payment_method = ?',
      [paymentMethod],
    );
  }
  Future<List<Map<String, dynamic>>> queryMedicalLogsByDate(String startDate, String endDate) async {
    final db = await database;
    return await db.query(
      'medical_logs',
      where: 'date_added BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date_added DESC',
    );
  }
  Future<List<Map<String, dynamic>>> getAllSalariesWithUserDetails({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String query = '''
    SELECT s.*, u.full_name, u.email 
    FROM salaries s 
    LEFT JOIN users u ON u.id = s.user_id
  ''';

    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      query += ' WHERE DATE(s.pay_date) BETWEEN ? AND ?';
      args.add(DateFormat('yyyy-MM-dd').format(startDate));
      args.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    return await db.rawQuery(query, args);
  }

  Future<void> recoverMedicine(Map<String, dynamic> medicine) async {
    final db = await database;

    await db.insert('medicines', {
      'name': medicine['name'],
      'company': medicine['company'],
      'total_quantity': medicine['total_quantity'],
      'remaining_quantity': medicine['remaining_quantity'],
      'buy': medicine['buy'],
      'price': medicine['price'],
      'batchNumber': medicine['batchNumber'],
      'manufacture_date': medicine['manufacture_date'],
      'expiry_date': medicine['expiry_date'],
      'added_by': medicine['added_by'],
      'discount': medicine['discount'],
      'added_time': medicine['added_time'],
      'unit': medicine['unit'],
      'businessName': medicine['businessName'],
    });

    // Optional: delete from deleted_medicines table
    await db.delete(
      'deleted_medicines',
      where: 'id = ?',
      whereArgs: [medicine['id']],
    );
  }




// 9. Get all medicines
  Future<List<Map<String, dynamic>>> queryAllMedicines() async {
    final db = await database;
    return await db.rawQuery('SELECT * FROM  medicines');
  }
  // Function to get all receipts from the 'sales' table
  Future<List<Map<String, dynamic>>>  getAllReceipts(String start, String end) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT * FROM sales
    WHERE confirmed_time BETWEEN ? AND ?
    ORDER BY confirmed_time DESC
  ''', [start, end]);
  }



  Future<List<Map<String, dynamic>>> queryAllRows(String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }

  Future<Map<String, dynamic>?> getBusinessDetails() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query('businesses', limit: 1);
    if (result.isNotEmpty) {

      return result.first;
    }
    return null;
  }
  Future<void> disableUser(int userId) async {
    final db = await database;

    await db.update(
      'users',
      {'is_disabled': 1}, // Mark the user as disabled
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
  Future<void> updateUserStatus(Map<String, dynamic> updatedStatus, int userId) async {
    final db = await openDatabase('path_to_your_database.db');
    await db.update(
      'users',
      updatedStatus,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // Add the query to filter sales by month and year
  Future<List<Map<String, dynamic>>> querySalesByMonthYear(int month, int year) async {
    final db = await instance.database;
    final result = await db.query(
      'sales', // Assuming you have a sales table
      where: 'strftime("%m", sale_date) = ? AND strftime("%Y", sale_date) = ?',
      whereArgs: [month.toString().padLeft(2, '0'), year.toString()],
    );
    return result;
  }


  Future<Map<String, dynamic>?> getBusinessInfo() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query('businesses', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }
// Fetch all business data from the database
  Future<List<Map<String, dynamic>>> getAllBusinesses() async {
    final db = await database;
    return await db.query('businesses');
  }
  Future<int> deleteBusiness(int id) async {
    final db = await database;
    return await db.delete(
      'businesses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isBusinessFieldExists(String field, String value) async {
    final db = await database;
    final result = await db.query(
      'businesses',
      where: '$field = ?',
      whereArgs: [value],
      limit: 1,
    );
    return result.isNotEmpty;
  }
  // Add a new company to the database
  Future<int> addCompany(String name, String address) async {
    final db = await database;
    return await db.insert('companies', {
      'name': name,
      'address': address,
    });
  }

  // Method to fetch all companies from the database
  Future<List<String>> getCompanies() async {
    final db = await instance.database;
    final result = await db.query('companies', columns: ['name']); // Assuming the column name is 'name'
    return result.map((company) => company['name'] as String).toList();
  }

  // Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < 2) {
  //     // Future updates can be handled here
  //   }
  // }
  Future<Map<String, dynamic>?> getMedicineById(int id) async {
    final db = await database;
    final result = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return result.first; // Return the first match
    }
    return null; // No medicine found
  }
  Future<Object?> getBusinessLogo(int businessId) async {
    Database db = await instance.database;
    var result = await db.query(
      'business',
      columns: ['logoPath'],
      where: 'id = ?',
      whereArgs: [businessId],
    );
    if (result.isNotEmpty) {
      return result.first['logoPath'];  // Return the logo path or URL
    }
    return null;
  }

  // ✅ Register User
  Future<int> registerUser(String fullName, String email, String phone, String role, String professional, String password, [String? profilePicture]) async {
    Database db = await instance.database;
    String hashedPassword = sha256.convert(utf8.encode(password)).toString();

    try {
      return await db.insert('users', {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'professional': professional,
        'password': hashedPassword,
        'profile_picture': profilePicture ?? '',  // ✅ Store profile picture if available
      });
    } catch (e) {
      return -1; // Email already exists or some error occurred
    }
  }


  Future<void> migrateStoreToMedicinesWithDiscount({
    required String businessName,
    required double discountValue, // discount will be added here
  }) async {
    final db = await DatabaseHelper.instance.database;

    final products = await db.query(
      'store',
      where: 'business_name = ?',
      whereArgs: [businessName],
    );

    for (final item in products) {
      await db.insert('medicines', {
        'name': item['name'],
        'company': item['company'],
        'total_quantity': item['quantity'],
        'remaining_quantity': item['quantity'], // initial remaining = total
        'unit': item['unit'], // fixed extra space in key
        'price': (item['price'] as num).toDouble(),
        'buy_price': (item['buy'] as num).toDouble(),
        'discount': (discountValue as num).toDouble(),
        'manufacture_date': item['manufacture_date'],
        'expiry_date': item['expiry_date'],
        'batch_number': item['batchNumber'], // changed to match typical column naming
        'added_by': item['added_by'],
        'date_added': item['added_time'], // renamed for consistency
      });


      await db.delete('store', where: 'id = ?', whereArgs: [item['id']]);
    }

    print('Migrated medicines from store to medicines for $businessName with $discountValue% discount.');
  }
  Future<void> savePaymentData(Map<String, dynamic> paymentData) async {
    final db = await database;

    await db.insert(
      'payments',
      {
        'payment_id': paymentData['payment_id'],
        'amount': paymentData['amount'],
        'payment_status': paymentData['payment_status'],
        'transaction_id': paymentData['transaction_id'],
        'payment_method': paymentData['payment_method'],
        'customer_name': paymentData['customer_name'],
        'customer_email': paymentData['customer_email'],
        'sale_id': paymentData['sale_id'],
        'sale_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()), // Current timestamp
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  Future<List<Map<String, dynamic>>> fetchMedicines({
    String searchQuery = '',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery.isNotEmpty) {
      whereClause = '(name LIKE ? OR company LIKE ? OR expiry_date LIKE ?)';
      whereArgs.addAll([
        '%$searchQuery%',
        '%$searchQuery%',
        '%$searchQuery%',
      ]);
    }

    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'expiry_date BETWEEN ? AND ?';
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
    }

    if (whereClause.isEmpty) {
      return await db.query('medicines');
    } else {
      return await db.query(
        'medicines',
        where: whereClause,
        whereArgs: whereArgs,
      );
    }
  }
  Future<int> insertOtherProductLog(Map<String, dynamic> log) async {
    Database? db = await instance.database;
    return await db!.insert('other_product_logs', log);
  }
// Update synced flag for medicine by id
  Future<int> updateMedicineSyncedFlag(int id, int synced) async {
    final db = await database;
    return await db.update(
      'medicines', // your table name
      {'synced': synced},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertBusiness(String tableName, Map<String, dynamic> businessData) async {
    final db = await database;

    // Assuming you are using SQLite, here is how you can insert the data:
    return await db.insert(
      tableName,
      businessData,
      conflictAlgorithm: ConflictAlgorithm.replace,  // or any appropriate conflict resolution
    );
  }

  // Insert installation date when the app is first launched
  Future<void> insertInstallationDate(String installationDate) async {
    final db = await database;
    await db.insert(
      'user_subscription',
      {'installation_date': installationDate, 'subscription_status': 'trial'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  // Fetch business by ID with error handling
  Future<Map<String, dynamic>?> getBusinessById(int id) async {
    try {
      Database db = await instance.database;
      List<Map<String, dynamic>> result = await db.query(
        table,
        where: '$columnId = ?',
        whereArgs: [id],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error fetching business by ID: $e');
      return null;
    }
  }

// Update business by ID with error handling
  Future<int> updateBusiness(int id, Map<String, dynamic> updatedData) async {
    try {
      Database db = await instance.database;
      return await db.update(
        table,
        updatedData,
        where: '$columnId = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error updating business: $e');
      return 0; // Return 0 to indicate failure
    }
  }
  Future<int> insertMedicine(Map<String, dynamic> medicine) async {
    final db = await instance.database;
    return await db.insert('medicines', medicine);
  }
  Future<String?> getBusinessName(String userId) async {
    // Assuming you have a DatabaseHelper class for handling DB queries
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      'users', // The table where the business name is stored
      columns: ['businessName'], // Adjust the column name to match your DB schema
      where: 'id = ?', // Assuming 'id' is the column used for user identification
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      return result.first['businessName'] as String?;
    } else {
      return null; // Return null if no business name is found
    }
  }

  // Update User Details
  Future<int> updateUser(Map<String, dynamic> updatedData, int userId) async {
    Database db = await instance.database;

    // Prepare the updated data for the database
    Map<String, dynamic> updateMap = {
      'full_name': updatedData['full_name'],
      'email': updatedData['email'],
      'phone': updatedData['phone'],
      'professional': updatedData['professional'],
      'businessName': updatedData['businessName'],
      'profile_picture': updatedData['profile_image'],
    };

    // Only add the password field if it's not empty
    if (updatedData['password'] != null && updatedData['password'].isNotEmpty) {
      updateMap['password'] = updatedData['password'];
    }

    // Perform the update query on 'users' table
    int result = await db.update(
      'users',
      updateMap,
      where: 'id = ?',
      whereArgs: [userId],
    );

    return result;
  }
  Future<List<String>> getBusinessNames() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'businesses',
      columns: ['business_name'],
    );

    return results.map((row) => row['business_name'].toString()).toList();
  }

  Future<bool> verifyResetCode(String email, String resetCode) async {
    final db = await database;
    var user = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (user.isEmpty) return false;

    var userData = user.first;

    // Explicitly cast Object? to int
    int failedAttempts = (userData['failed_attempts'] as int?) ?? 0;
    int lastAttemptTime = (userData['last_attempt_time'] as int?) ?? 0;

    int currentTime = DateTime.now().millisecondsSinceEpoch;
    int lockoutDuration = 5 * 60 * 1000; // 5 minutes in milliseconds

    // Check if user is locked out
    if (failedAttempts >= 5 && (currentTime - lastAttemptTime) < lockoutDuration) {
      return false; // User is locked out
    }

    if (userData['reset_code'] == resetCode) {
      // Reset failed attempts on success
      await db.update(
        'users',
        {'failed_attempts': 0, 'last_attempt_time': 0},
        where: 'email = ?',
        whereArgs: [email],
      );
      return true;
    } else {
      // Increment failed attempts
      failedAttempts += 1;
      await db.update(
        'users',
        {'failed_attempts': failedAttempts, 'last_attempt_time': currentTime},
        where: 'email = ?',
        whereArgs: [email],
      );
      return false;
    }
  }

  // Update Profile Picture
  Future<int> updateProfilePicture(int userId, String profilePicturePath) async {
    Database db = await instance.database;
    return await db.update(
      'users',
      {'profile_picture': profilePicturePath},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
  Future<int> addToCart(
      int userId,
      int medicineId,
      String medicineName,
      String company,
      int quantity,
      double price,
      String unit,
      ) async {
    final db = await database;

    // Current date and time
    String dateAdded = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // Prepare cart data
    final cartData = {
      'user_id': userId,
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'company': company,
      'quantity': quantity,
      'price': price,
      'unit': unit,
      'date_added': dateAdded,
    };

    // Step 1: Insert into local SQLite
    int localResult = await db.insert('cart', cartData);

    // Step 2: Sync with live server
    try {
      final response = await http.post(
        Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/sync_cart.php'), // replace with your real endpoint
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cartData),
      );

      if (response.statusCode == 200) {
        debugPrint('🟢 Cart synced successfully: ${response.body}');
      } else {
        debugPrint('🟠 Cart sync failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('🔴 Error syncing cart: $e');
    }

    return localResult;
  }

  Future<void> insertIndicatorDataFull(Map<String, dynamic> rowData) async {
    final db = await database;
    await db.insert(
      'indicator_data',
      rowData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ✅ Login User
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    Database db = await instance.database;
    String hashedPassword = sha256.convert(utf8.encode(password)).toString();

    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedPassword],
    );

    return result.isNotEmpty ? result.first : null;
  }

  // ✅ Get User By Email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<String?> getProfilePicture(int userId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      columns: ['profile_picture'],
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      return result.first['profile_picture'];
    }
    return null;
  }

  final lock = Lock();

  Future<int> updatePassword(String email, String newPassword) async {
    return lock.synchronized(() async {
      print("🔐 Starting password update for: $email");

      Database db = await instance.database;
      String hashedPassword = sha256.convert(utf8.encode(newPassword)).toString();
      print("🔑 Hashed new password: $hashedPassword");

      // Get old password before update in case rollback is needed
      List<Map<String, dynamic>> existingUser = await db.query(
        'users',
        columns: ['password'],
        where: 'email = ?',
        whereArgs: [email],
      );

      if (existingUser.isEmpty) {
        print("❌ User not found locally.");
        return 0;
      }

      String oldPassword = existingUser.first['password'];
      print("📦 Old password (hashed): $oldPassword");

      // Update local SQLite DB
      int result = await db.update(
        'users',
        {'password': hashedPassword},
        where: 'email = ?',
        whereArgs: [email],
      );
      print("📲 Local DB update result: $result");

      // Send update to PHP server
      try {
        print("🌐 Sending password update to remote server...");
        final response = await http.post(
          Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/update_password.php'),
          body: {
            'email': email,
            'password': hashedPassword,
          },
        );

        print("🌐 Server responded: ${response.statusCode} → ${response.body}");

        if (response.statusCode == 200 && response.body.toLowerCase().contains('success')) {
          print("✅ Password updated successfully on remote server.");
        } else {
          print("❌ Remote server update failed: ${response.body}");
          // Rollback local update
          await db.update(
            'users',
            {'password': oldPassword},
            where: 'email = ?',
            whereArgs: [email],
          );
          print("🔁 Local DB rollback complete.");
          return 0;
        }
      } catch (e) {
        print("⚠️ Exception during remote update: $e");
        // Rollback local update
        await db.update(
          'users',
          {'password': oldPassword},
          where: 'email = ?',
          whereArgs: [email],
        );
        print("🔁 Local DB rollback complete after exception.");
        return 0;
      }

      print("🎉 Password update complete on both local and remote.");
      return result;
    });
  }



  // Retrieve User by ID
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    return result.isNotEmpty ? result.first : null;
  }

  // ✅ Log Activity
  Future<int> logActivity(int userId, String action) async {
    Database db = await instance.database;
    return await db.insert('logs', {'user_id': userId, 'action': action});
  }

  // ✅ Get Logs
  Future<List<Map<String, dynamic>>> getLogs() async {
    Database db = await instance.database;
    return await db.query('logs', orderBy: 'timestamp DESC');
  }

  Future<int> deleteMedicine(int id) async {
    final db = await database;
    return await db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSalesReports(int userId) async {
    Database db = await instance.database;

    // Get the user's role based on the userId
    List<Map<String, dynamic>> user = await db.query(
      'users',
      columns: ['role'],
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (user.isNotEmpty) {
      String userRole = user.first['role']; // Role of the user

      if (userRole == 'admin') {
        // Admin can see all sales reports
        return await db.query(
          'sales_reports',
          orderBy: 'generated_at DESC',
        );
      } else {
        // Non-admin users can only see their own sales reports
        return await db.query(
          'sales_reports',
          where: 'user_id = ?', // Ensure the query filters by user_id for non-admin users
          whereArgs: [userId],
          orderBy: 'generated_at DESC',
        );
      }
    } else {
      throw Exception("User not found");
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''      
      CREATE TABLE medicines (
        CREATE TABLE IF NOT EXISTS medicines (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  company TEXT NOT NULL,
  total_quantity INTEGER NOT NULL,
  remaining_quantity INTEGER NOT NULL,
  buy REAL NOT NULL,
  price REAL NOT NULL,
  batchNumber TEXT NOT NULL,
  manufacture_date TEXT NOT NULL,
  expiry_date TEXT NOT NULL,
  added_by TEXT NOT NULL,
  discount REAL,
  added_time TEXT,
  unit TEXT,
  businessName TEXT,
   synced INTEGER DEFAULT 0
);
Stores the current timestamp
      )
    ''');
  }

  Future<void> addMedicine(
      String name,
      String company,
      int totalQuantity,
      double remainingQuantity,
      double buy,
      String price,
      String batchNumber,
      String manufactureDate,
      String expiryDate,
      String addedBy,
      String discount,
      String addedTime,
      String unit,
      String businessName,
      ) async {
    final db = await database;

    try {
      await db.insert('medicines', {
        'name': name,
        'company': company,
        'total_quantity': totalQuantity,
        'remaining_quantity': remainingQuantity,
        'buy': buy,
        'price': price,
        'batchNumber': batchNumber,
        'manufacture_date': manufactureDate,
        'expiry_date': expiryDate,
        'added_by': addedBy,
        'discount': discount,
        'added_time': addedTime,
        'unit': unit,
        'businessName': businessName,
      });
      print('✅ Inserted $name successfully');
    } catch (e) {
      print('❌ Error inserting $name: $e');
    }
  }





  Future<List<Map<String, dynamic>>> getMedicinesByBusinessName(String businessName) async {
    final db = await database;
    return await db.query(
      'medicines',
      where: 'businessName = ?',
      whereArgs: [businessName],
    );
  }

  Future<List<Map<String, dynamic>>> getMedicinesByUserIdAndBusinessName(String userId, String businessName) async {
    final db = await database;

    final result = await db.query(
      'medicines',
      where: 'addedBy = ? AND businessName = ?',
      whereArgs: [userId, businessName],
    );

    print('Fetched medicines for userId: $userId, businessName: $businessName');
    return result;
  }
  Future<void> deleteUser(int id) async {
    final db = await instance.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
  Future<void> addMedicineToStore({
    required String name,
    required String company,
    required int quantity,
    required double buy_price,
    required double price,
    required String unit,
    required String batchNumber,
    required String manufactureDate,
    required String expiryDate,
    required String addedBy,
    required String businessName,
    required String createdAt,
  }) async {
    final db = await database;

    await db.insert(
      'store',
      {
        'name': name,
        'company': company,
        'quantity': quantity,
        'buy_price': buy_price,
        'price': price,
        'unit': unit,
        'batchNumber': batchNumber,
        'manufacture_date': manufactureDate,
        'expiry_Date': expiryDate,
        'added_by': addedBy,
        'business_name': businessName,
        'added_time': createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }



// In your DatabaseHelper class

  Future<List<Map<String, dynamic>>> getAllMedicines() async {
    final db = await database;
    var result = await db.query('store'); // Query the 'store' table to fetch all rows
    return result; // Return the result
  }
// in DatabaseHelper
  Future<double> calculateProfitOnFinishedMedicines() async {
    final db = await database;

    // medicines finished or out of stock
    final result = await db.query(
      'medicines',
      where: 'remaining_quantity <= 0',
    );

    double totalProfit = 0;

    for (final row in result) {
      final totalQuantity = (row['total_quantity'] ?? 0) is int
          ? row['total_quantity'] as int
          : int.tryParse(row['total_quantity'].toString()) ?? 0;

      final sellingPrice = double.tryParse(row['price'].toString()) ?? 0;
      final buyingPrice = double.tryParse(row['buy'].toString()) ?? 0;

      final totalSales = totalQuantity * sellingPrice;
      final totalCost = totalQuantity * buyingPrice;
      final profit = totalSales - totalCost;

      totalProfit += profit;
    }

    return totalProfit;
  }
  //
  // Future<void> checkSubscriptionStatusAndLogoutIfNeeded(BuildContext context) async {
  //   bool isExpired = await isPaymentExpired();
  //
  //   print('Is subscription expired? $isExpired'); // Debug log
  //
  //   if (isExpired) {
  //     await showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (context) => AlertDialog(
  //         title: Text('Subscription Expired'),
  //         content: Text('Your subscription has expired. You need to pay now!'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: Text('OK'),
  //           ),
  //         ],
  //       ),
  //     );
  //
  //     // 🚨 Clear session/local storage or call your logout logic
  //     await logoutUser(); // <-- You must define this
  //
  //     // 🚀 Navigate to PaymentScreen
  //     Navigator.of(context).pushAndRemoveUntil(
  //       MaterialPageRoute(builder: (context) => PaymentScreen()),
  //           (route) => false,
  //     );
  //   }
  // }
  Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Or only remove specific keys like prefs.remove('user')
    print('User session cleared.');
  }

  Future<int> updateOtherProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.update(
      'other_product',
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
  }
  Future<List<String>> getAllUserEmails() async {
    final db = await database;
    final result = await db.query(
      'users',
      columns: ['email'],
    );

    return result
        .map((row) => row['email']?.toString() ?? '')
        .where((email) => email.isNotEmpty)
        .toList();
  }
  Future<void> markCustomerEmailSent(int paymentId) async {
    final db = await database;
    await db.update(
      'payment_transactions',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [paymentId],
    );
  }

  Future<void> updateMedicine(Map<String, dynamic> medicine) async {
    final db = await database;

    // Ensure default values to prevent null issues
    medicine['total_quantity'] ??= 0;
    medicine['remaining_quantity'] ??= 0;
    medicine['buy'] ??= 0.0;
    medicine['price'] ??= 0.0;
    medicine['discount'] ??= 0.0;
    medicine['synced'] ??= 0;

    // Debug print to verify all fields before updating
    print('Updating medicine with:');
    medicine.forEach((key, value) => print('$key: $value'));

    await db.rawUpdate(
      '''
    UPDATE medicines
    SET 
      name = ?, 
      company = ?, 
      total_quantity = ?, 
      remaining_quantity = ?, 
      buy = ?, 
      price = ?, 
      batchNumber = ?, 
      manufacture_date = ?, 
      expiry_date = ?, 
      added_by = ?, 
      discount = ?, 
      added_time = ?, 
      unit = ?, 
      businessName = ?, 
      synced = ?
    WHERE id = ?
    ''',
      [
        medicine['name'],               // String
        medicine['company'],            // String
        medicine['total_quantity'],     // int
        medicine['remaining_quantity'], // int
        medicine['buy'],                // double
        medicine['price'],              // double
        medicine['batchNumber'],        // String
        medicine['manufacture_date'],   // String (or ISO format date)
        medicine['expiry_date'],        // String (or ISO format date)
        medicine['added_by'],           // String
        medicine['discount'],           // double
        medicine['added_time'],         // String (timestamp)
        medicine['unit'],               // String
        medicine['businessName'],       // String
        medicine['synced'],             // int (0 or 1)
        medicine['id'],                 // int (primary key for WHERE clause)
      ],
    );

    print('Medicine updated in the database successfully.');
  }

// Add new medicine record to the database
  Future<int> readdMedicine(Map<String, dynamic> medicine) async {
    final db = await database;
    return await db.insert('medicines', medicine);
  }

// Replace (update) an existing medicine record by id
  Future<int> replaceMedicine(int id, Map<String, dynamic> medicine) async {
    final db = await database;
    return await db.update(
      'medicines',
      medicine,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  Future<int> ReupdateMedicine(int id, Map<String, dynamic> medicine) async {
    final db = await database;
    return await db.update(
      'medicines',
      medicine,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertUserIfNotExists(Map<String, dynamic> user) async {
    final db = await database;
    var result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [user['email']],
    );

    if (result.isEmpty) {
      await db.insert('users', user);
    }
  }
  Future<Map<String, dynamic>?> loginRemote(String email, String password) async {
    try {
      // Hash the password for both remote and local login
      final hashedPassword = sha256.convert(utf8.encode(password)).toString();

      // Check internet connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult != ConnectivityResult.none) {
        // Attempt remote login
        final url = Uri.parse("http://ephamarcysoftware.co.tz/ephamarcy/login.php");
        final response = await http.post(url, body: {
          'email': email,
          'password': password, // If server expects plain password
          // use 'hashedPassword' if server expects hashed
        });

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            // Optionally cache user data locally
            final db = await DatabaseHelper.instance.database;
            await db.insert(
              'users',
              {
                'email': data['user']['email'],
                'password': hashedPassword,
                'name': data['user']['name'],
                // Add other fields as needed
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            return data['user'];
          }
        }
      }

      // If remote fails or no internet, try local login
      final db = await DatabaseHelper.instance.database;
      final localResult = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, hashedPassword],
      );

      if (localResult.isNotEmpty) {
        return localResult.first;
      }
    } catch (e) {
      debugPrint("Login error: $e");
    }

    return null;
  }
  // Fetch out-of-stock medicines (quantity = 0)
  Future<List<Map<String, dynamic>>> fetchOutOfStockMedicines() async {
    final db = await database;
    return await db.query(
      'medicines',
      where: 'quantity = ?',
      whereArgs: [0],  // Filter for medicines with 0 quantity
    );
  }

  Future<void> storeResetCode(String email, String code, int expiry) async {
    final db = await database;
    await db.update(
      'users',
      {
        'reset_code': code,
        'reset_code_expiry': expiry,
      },
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<Map<String, dynamic>?> getResetCodeAndExpiry(String email) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      columns: ['reset_code', 'reset_code_expiry'],
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // Method to get user by email and phone
  Future<Map<String, dynamic>?> getUserByEmailAndPhone(String email, String phone,) async {
    final db = await database;
    var result = await db.query(
      'users', // Replace 'users' with your actual table name
      where: 'email = ? AND phone = ?',
      whereArgs: [email, phone],
    );

    if (result.isNotEmpty) {
      return result.first;
    } else {
      return null;
    }
  }
  // ✅ Cancel Bill
  Future<int> cancelBill(int saleId, int userId, String role) async {
    Database db = await instance.database;
    if (role == 'admin') {
      await db.delete('sales_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await db.delete('pending_bills', where: 'sale_id = ?', whereArgs: [saleId]);
      await db.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    } else {
      await db.delete('sales_items', where: 'sale_id = ? AND sale_id IN (SELECT sale_id FROM pending_bills WHERE user_id = ?)', whereArgs: [saleId, userId]);
      await db.delete('pending_bills', where: 'sale_id = ? AND user_id = ?', whereArgs: [saleId, userId]);
      await db.delete('sales', where: 'id = ? AND id IN (SELECT sale_id FROM pending_bills WHERE user_id = ?)', whereArgs: [saleId, userId]);
    }
    return 1;
  }
}
