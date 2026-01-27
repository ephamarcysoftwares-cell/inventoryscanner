// import 'dart:convert';
// import 'dart:io';
// import 'package:bitsdojo_window/bitsdojo_window.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:cron/cron.dart';
// import 'package:flutter_email_sender/flutter_email_sender.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:http/http.dart' as http;
// import 'package:launch_at_startup/launch_at_startup.dart';
// import 'package:mailer/mailer.dart' as mailer;
// import 'package:mailer/smtp_server.dart';
// import 'package:mailer/smtp_server/gmail.dart';
// import 'package:package_info_plus/package_info_plus.dart';
// import 'package:path/path.dart';
// import 'package:path/path.dart' as p;
// import 'package:screen_retriever/screen_retriever.dart';
// import 'dart:async';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
// import 'package:stock_and_inventory_software/whatsapp/network.dart' hide startPythonServer;
// import 'package:tray_manager/tray_manager.dart';
// import 'package:stock_and_inventory_software/payment/PaymentTransaction.dart';
// import 'package:stock_and_inventory_software/updater/update_service.dart';
// import 'package:window_manager/window_manager.dart';
// import 'API/payment_sync_service.dart';
// import 'AUTOMATICAL_REPORT_SENT/MedicineStockNotifier.dart';
// import 'AUTOMATICAL_REPORT_SENT/MonthlyReportScheduler.dart';
// import 'AUTOMATICAL_REPORT_SENT/Other_product.dart';
// import 'AUTOMATICAL_REPORT_SENT/OutOfStockNotifier.dart';
// import 'AUTOMATICAL_REPORT_SENT/OutOfStockOtherProductNotfier.dart';
// import 'AUTOMATICAL_REPORT_SENT/WeeklyReportScheduler.dart';
// import 'AUTOMATICAL_REPORT_SENT/YearlyReportScheduler.dart';
// import 'AUTOMATICAL_REPORT_SENT/expire product.dart';
// import 'AUTOMATICAL_REPORT_SENT/sales report sent.dart';
// import 'BACKUP/backup.dart';
// import 'DB/backup_service.dart';
// import 'DBSYCNIZATION/medical_logs sync.dart';
// import 'DBSYCNIZATION/sale_sync_service.dart';
// import 'DBSYCNIZATION/sync_service.dart';
// import 'DBSYCNIZATION/sync_user.dart';
// import 'Diary/event_notifier.dart';
// import 'Python inslation/installtion.dart';
// import 'QR Code generator/daily summary.dart';
// import 'SMS/sms_periodicall.dart';
// import 'SMS/sms_reminder.dart' hide PeriodicReminderScheduler;
// import 'SplashScreen/splash_screen.dart';
// import 'package:synchronized/synchronized.dart'; // <<< ADDED FOR LOCKING
//
// import 'login_screen.dart'; // For accessing file paths
//
// // GlobalKey for Navigator
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//
// // **GLOBAL LOCK FOR ALL DATABASE WRITE OPERATIONS**
// final _databaseLock = Lock(); // <<< ADDED
//
// // If you want to allow self-signed certificates for testing only
// class MyHttpOverrides extends HttpOverrides {
//   @override
//   HttpClient createHttpClient(SecurityContext? context) {
//     final client = super.createHttpClient(context);
//     client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
//     return client;
//   }
// }
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // 1. Database Setup (must be done early)
//   if (!kIsWeb) {
//     HttpOverrides.global = MyHttpOverrides();
//     sqfliteFfiInit();
//     databaseFactory = databaseFactoryFfi;
//   }
//
//   try {
//     // --- Initial setup (No DB access that clashes with Trial check) ---
//     final updateService = UpdateService();
//     await updateService.init();
//     await updateService.checkForUpdatesOncePer24Hours(
//       onProgress: (progress) {
//         print('Update download progress: ${(progress * 100).toStringAsFixed(1)}%');
//       },
//     );
//
//     // Setup window (Windows only)
//     if (!kIsWeb && Platform.isWindows) {
//       await windowManager.ensureInitialized();
//
//       final display = await screenRetriever.getPrimaryDisplay();
//       final screenWidth = display.size.width;
//       final screenHeight = display.size.height;
//
//       const minWidth = 600;
//       const minHeight = 400;
//       const maxWidth = 1200;
//       const maxHeight = 900;
//
//       int windowWidth = (screenWidth * 0.6).round();
//       int windowHeight = (screenHeight * 0.6).round();
//
//       windowWidth = windowWidth.clamp(minWidth, maxWidth);
//       windowHeight = windowHeight.clamp(minHeight, maxHeight);
//
//       WindowOptions windowOptions = WindowOptions(
//         size: Size(windowWidth.toDouble(), windowHeight.toDouble()),
//         center: true,
//         backgroundColor: Colors.teal,
//         title: "DIGITAL BUSINESS SOFTWARE",
//         titleBarStyle: TitleBarStyle.normal,
//       );
//
//       await windowManager.waitUntilReadyToShow(windowOptions, () async {
//         await windowManager.show();
//         await windowManager.focus();
//         await windowManager.setTitleBarStyle(TitleBarStyle.normal);
//         await windowManager.setMinimumSize(Size(minWidth.toDouble(), minHeight.toDouble()));
//         await windowManager.setMaximumSize(Size(maxWidth.toDouble(), maxHeight.toDouble()));
//       });
//     }
//
//     // Setup auto-start (Windows only)
//     if (Platform.isWindows) {
//       final info = await PackageInfo.fromPlatform();
//       launchAtStartup.setup(
//         appName: info.appName,
//         appPath: Platform.resolvedExecutable,
//         packageName: info.packageName,
//       );
//       await launchAtStartup.enable();
//     }
//
//     // --- Critical Await Block (Sequential DB access) ---
//     // These tasks are now run in sequence before background services start.
//     // NOTE: This assumes these methods use the new DatabaseHelper methods
//     // that incorporate the global lock for writes.
//     ExpiredMedicineNotifier().checkAndSendExpiredMedicines();
//     EventNotifier.notifyUpcomingEvents();
//     startPythonServer();
//     BackupService.sendBackupIfNeeded();
//     BackupService.sendBackupEmail();
//     backgroundPaymentCheck();
//     installPythonAndDependencies(); // Moved up to ensure it runs before services that rely on it.
//
//   } catch (e, stack) {
//     print('Error during initialization: $e\n$stack');
//   }
//
//   runApp(MyApp());
//
//   // Auto-logout if payment is overdue - This check is now safely handled
//   // by TrialDataPage's logic via isPaymentExpired().
//   Future(() async {
//     // Check after the main UI is built
//     await Future.delayed(Duration(milliseconds: 500));
//     final expired = await isPaymentExpired();
//     if (expired) {
//       navigatorKey.currentState?.pushAndRemoveUntil(
//         MaterialPageRoute(builder: (_) => PaymentScreen()),
//             (route) => false,
//       );
//     }
//   });
//
//   // Start other background services asynchronously (non-blocking)
//   // All periodic and sync services are started here, where they will rely
//   // on the global lock for safe concurrent database access.
//   Future(() async {
//     try {
//       final notifier = OutOfStockNotifier();
//       notifier.start();
//
//       MedicalLogSyncService.startPeriodicSync();
//       UserSyncService.startPeriodicSync();
//       SaleSyncService.syncUnsyncedSales();
//       PaymentSyncService.startPeriodicSync();
//
//       // Uncomment other schedulers as needed, knowing they now use the lock.
//       // ReportScheduler().start();
//       // DailySummaryReportScheduler().start();
//       // WeeklyReportScheduler().start();
//       // MonthlyReportScheduler().start();
//       // PeriodicReminderScheduler().start();
//       // ExpiredMedicineNotifier().start();
//       // MedicineStockNotifier().start();
//       // OutOfStockOtherProductNotifier().start();
//
//
//       if (Platform.isWindows) {
//         await TrayManager.instance.setIcon('assets/try.ico');
//         await TrayManager.instance.setToolTip('STOCK & INVENTORY SOFTWARE');
//         await TrayManager.instance.setContextMenu(Menu(items: [
//           MenuItem(key: 'show', label: 'Show App'),
//           MenuItem(key: 'exit', label: 'Exit'),
//         ]));
//         TrayManager.instance.addListener(MyTrayListener());
//
//         windowManager.setPreventClose(true);
//         windowManager.addListener(MyWindowListener());
//       }
//     } catch (e, stack) {
//       print('Error during background services startup: $e\n$stack');
//     }
//   });
// }
//
// // ... (MyTrayListener and MyWindowListener classes remain unchanged) ...
//
// // Tray listener
// class MyTrayListener with TrayListener {
//   @override
//   void onTrayIconMouseDown() {
//     TrayManager.instance.popUpContextMenu();
//   }
//
//   @override
//   void onTrayMenuItemClick(MenuItem menuItem) async {
//     switch (menuItem.key) {
//       case 'show':
//         await windowManager.show();
//         await windowManager.focus();
//         break;
//       case 'exit':
//         TrayManager.instance.destroy();
//         exit(0);
//     }
//   }
// }
//
// // Window listener with close confirmation dialog
// class MyWindowListener with WindowListener {
//   @override
//   void onWindowClose() async {
//     // Ensure we have a context from the navigatorKey before showing the dialog
//     final BuildContext? context = navigatorKey.currentState?.context;
//     if (context == null) {
//       // If context is somehow null, fall back to the original behavior (hide)
//       await windowManager.hide();
//       return;
//     }
//
//     final action = await showDialog<String>(
//       context: context,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         elevation: 10,
//         backgroundColor: Colors.transparent, // for gradient to show nicely
//         child: Center(
//           child: Container(
//             width: 400, // smaller width
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(20),
//               gradient: LinearGradient(
//                 colors: [Colors.blue.shade50, Colors.blue.shade100],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black26,
//                   blurRadius: 15,
//                   offset: Offset(0, 5),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Row(
//                   children: [
//                     Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Text(
//                         'Close Application?',
//                         style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.blueGrey.shade900),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 15),
//                 Text(
//                   'The software will continue running in the background to handle synchronization, reports, and alerts. '
//                       'This is recommended. Choose "Stay on App" to keep the window open.',
//                   style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade700),
//                   textAlign: TextAlign.justify,
//                 ),
//                 const SizedBox(height: 25),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     // Stay on App Button
//                     Expanded(
//                       child: OutlinedButton.icon(
//                         onPressed: () => Navigator.of(context).pop('cancel'),
//                         icon: Icon(Icons.cancel, color: Colors.blue),
//                         label: Text('Stay on App', style: TextStyle(color: Colors.blue)),
//                         style: OutlinedButton.styleFrom(
//                           side: BorderSide(color: Colors.blue),
//                           padding: EdgeInsets.symmetric(vertical: 12),
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10)),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     // Continue in Background Button
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () => Navigator.of(context).pop('hide'),
//                         icon: Icon(Icons.visibility_off),
//                         label: Text('Background'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.green,
//                           padding: EdgeInsets.symmetric(vertical: 12),
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10)),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     // Close Completely Button
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () => Navigator.of(context).pop('exit'),
//                         icon: Icon(Icons.close),
//                         label: Text('Close'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.red,
//                           padding: EdgeInsets.symmetric(vertical: 12),
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10)),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//
//
//     // CRITICAL CHANGE: Only exit if the user explicitly chose 'exit'
//     if (action == 'exit') {
//       // User chose to terminate
//       TrayManager.instance.destroy(); // Clean up tray icon
//       exit(0);
//     } else if (action == 'hide') {
//       // User chose 'hide', clicked 'Continue in Background'.
//       await windowManager.hide();
//     }
//   }
// }
//
//
//
// // Main app
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'STOCK&INVENTORY SOFTWARE',
//       theme: ThemeData(
//         primaryColor: Colors.teal,
//         appBarTheme: AppBarTheme(
//           backgroundColor: Colors.teal,
//           elevation: 4,
//           centerTitle: true,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
//           ),
//           titleTextStyle: TextStyle(
//             color: Colors.white,
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//           iconTheme: IconThemeData(color: Colors.white),
//         ),
//       ),
//       home: SplashScreen(),
//       navigatorKey: navigatorKey,
//     );
//   }
// }
//
//
// class TrialDataPage extends StatefulWidget {
//   @override
//   _TrialDataPageState createState() => _TrialDataPageState();
// }
//
// class _TrialDataPageState extends State<TrialDataPage> {
//   // Use a singleton pattern or inject this to be safe, but kept as local for scope
//   final DatabaseHelper _dbHelper = DatabaseHelper();
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeTrialPeriod();
//     sendEmailWithIp(); // This uses networking and an external DB check, which is fine outside the lock scope.
//   }
//
//   Future<String> copyIconToTemp() async {
//     final bytes = await rootBundle.load('assets/app_icon.ico');
//     final tempDir = Directory.systemTemp;
//     final tempIconPath = p.join(tempDir.path, 'app_icon.ico');
//     final file = File(tempIconPath);
//
//     if (!await file.exists()) {
//       await file.writeAsBytes(bytes.buffer.asUint8List());
//     }
//
//     return tempIconPath;
//   }
//
//   Future<void> _initializeTrialPeriod() async {
//     try {
//       // READ operations are usually safe from write locks.
//       DateTime trialStartDate = await _dbHelper.getTrialStartDate();
//       DateTime currentDate = DateTime.now();
//       int daysPassed = currentDate.difference(trialStartDate).inDays;
//
//       if (daysPassed <= 30) {
//         _navigateTo(LoginScreen());
//       } else {
//         // This is a READ operation, but involves the main epharmacy.db
//         bool isExpired = await isPaymentExpired();
//         _navigateTo(isExpired ? PaymentScreen() : LoginScreen());
//       }
//     } catch (e) {
//       if (e.toString().contains("No trial start date found")) {
//         // WRITE operation is now wrapped in the global lock
//         await _dbHelper.insertTrialStartDate(DateTime.now());
//         _navigateTo(LoginScreen());
//       } else {
//         print('Error checking trial period: $e');
//       }
//     }
//   }
//
//   void _navigateTo(Widget screen) {
//     navigatorKey.currentState?.pushReplacement(
//       MaterialPageRoute(builder: (context) => screen),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: CircularProgressIndicator(),
//       ),
//     );
//   }
// }
//
// class DatabaseHelper {
//   static final _dbName = 'ePharmacy.db';
//   static final _dbVersion = 1;
//
//   static final _trialTable = 'trial';
//   static final _paymentsTable = 'payments';
//
//   static final columnStatus = 'status';
//   static final columnPaymentMethod = 'payment_method';
//   static final columnAmount = 'amount';
//   static final columnConfirmationCode = 'confirmation_code';
//   static final columnOrderTrackingId = 'order_tracking_id';
//   static final columnMerchantReference = 'merchant_reference';
//   static final columnTrialStartDate = 'trial_start_date';
//   static final columnPaymentTime = 'payment_time';
//
//   Database? _db;
//
//   Future<Database> get db async {
//     if (_db == null) {
//       _db = await _initDb();
//     }
//     return _db!;
//   }
//
//   Future<Database> _initDb() async {
//     // This is the payzz database path
//     final publicDir = Directory('C:/Users/Public/payzz');
//     if (!(await publicDir.exists())) {
//       await publicDir.create(recursive: true);
//     }
//     final path = join(publicDir.path, _dbName);
//     // Since this is called only once, it does not need to be locked.
//     return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
//   }
//
//   Future<void> _onCreate(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE $_trialTable (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         $columnTrialStartDate TEXT NOT NULL
//       )
//     ''');
//     db.execute('''
//       CREATE TABLE $_paymentsTable (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         $columnStatus TEXT NOT NULL,
//         $columnPaymentMethod TEXT NOT NULL,
//         $columnAmount TEXT NOT NULL,
//         $columnConfirmationCode TEXT NOT NULL,
//         $columnOrderTrackingId TEXT NOT NULL,
//         $columnMerchantReference TEXT NOT NULL,
//         $columnPaymentTime TEXT NOT NULL
//       )
//     ''');
//   }
//
//   // <<< FIXED: Locked Write Operation >>>
//   Future<void> insertTrialStartDate(DateTime trialStartDate) async {
//     await _databaseLock.synchronized(() async { // <<< LOCK ACQUIRED
//       final dbClient = await db;
//       await dbClient.insert(
//         _trialTable,
//         {
//           columnTrialStartDate: trialStartDate.toIso8601String(),
//         },
//         conflictAlgorithm: ConflictAlgorithm.replace,
//       );
//     }); // <<< LOCK RELEASED
//   }
//
//   // READ Operation - No lock needed (read locks are fine)
//   Future<DateTime> getTrialStartDate() async {
//     final dbClient = await db;
//     final result = await dbClient.query(_trialTable, limit: 1);
//     if (result.isNotEmpty) {
//       return DateTime.parse(result.first[columnTrialStartDate] as String);
//     } else {
//       throw Exception("No trial start date found.");
//     }
//   }
//
//   // <<< FIXED: Locked Write Operation >>>
//   Future<void> insertPaymentData(Map<String, dynamic> paymentData) async {
//     await _databaseLock.synchronized(() async { // <<< LOCK ACQUIRED
//       final dbClient = await db;
//       await dbClient.insert(
//         _paymentsTable,
//         paymentData,
//         conflictAlgorithm: ConflictAlgorithm.replace,
//       );
//     }); // <<< LOCK RELEASED
//   }
//
//   // READ Operation - No lock needed
//   Future<List<Map<String, dynamic>>> getAllPayments() async {
//     final dbClient = await db;
//     return await dbClient.query(_paymentsTable);
//   }
// }
//
// // ... (getWindowsMacAddress, storePaymentDate, getDatabase, isPaymentExpired, sendEmailWithIp remain unchanged but rely on the main process to handle concurrency with the other database) ...
//
// // NOTE: The functions getDatabase() and isPaymentExpired() use the
// // 'epharmacy.db' which is separate from 'ePharmacy.db' used by DatabaseHelper.
// // To fully secure the application, you would need a similar lock mechanism
// // wrapping all write operations to 'epharmacy.db' used by the sync services.
//
// Future<String> getWindowsMacAddress() async {
//   try {
//     final result = await Process.run('getmac', []);
//     if (result.exitCode == 0) {
//       final output = result.stdout.toString().split('\n');
//       for (var line in output) {
//         if (line.contains('-')) {
//           return line.split(' ')[0].trim();
//         }
//       }
//     }
//     return 'MAC address not found';
//   } catch (e) {
//     return 'Error fetching MAC address: $e';
//   }
// }
//
// Future<void> storePaymentDate(Map<String, dynamic> paymentData) async {
//   try {
//     String filePath = 'C:/Users/Public/payzz/payment_974801fa-4211-4f44-be39-dbfe5680f6c6.json';
//     File file = File(filePath);
//
//     if ( await file.exists()) {
//       String content = await file.readAsString();
//       Map<String, dynamic> existingData = jsonDecode(content);
//       existingData['payment_date'] = DateTime.now().toIso8601String();
//       await file.writeAsString(jsonEncode(existingData));
//     } else {
//       paymentData['payment_date'] = DateTime.now().toIso8601String();
//       file.writeAsString(jsonEncode(paymentData));
//     }
//   } catch (e) {
//     print("Error storing payment date: $e");
//   }
// }
//
// Future<Database> getDatabase() async {
//   String path;
//   if (Platform.isWindows) {
//     try {
//       final windowsDir = Directory('C:/Users/Public/epharmacy');
//       if (!(await windowsDir.exists())) {
//         await windowsDir.create(recursive: true);
//       }
//       path = join(windowsDir.path, 'epharmacy.db');
//     } catch (e) {
//       print('Failed to access or create C:/Users/Public/epharmacy, using fallback: $e');
//       final fallbackDir = await getDatabasesPath();
//       path = join(fallbackDir, 'epharmacy.db');
//     }
//   } else {
//     final dbDir = await getDatabasesPath();
//     path = join(dbDir, 'epharmacy.db');
//   }
//   return await openDatabase(path);
// }
//
// Future<bool> isPaymentExpired() async {
//   try {
//     final db = await getDatabase();
//     final List<Map<String, dynamic>> result = await db.rawQuery('''
//       SELECT payment_date, next_payment_date
//       FROM payment_transactions
//       WHERE status = 'Completed'
//       ORDER BY datetime(payment_date) DESC
//       LIMIT 1
//     ''');
//     if (result.isNotEmpty) {
//       final String? paymentDateStr = result[0]['payment_date'] as String?;
//       final String? nextPaymentDateStr = result[0]['next_payment_date'] as String?;
//       if (nextPaymentDateStr != null && nextPaymentDateStr.isNotEmpty) {
//         final DateTime nextPaymentDate = DateTime.parse(nextPaymentDateStr);
//         return DateTime.now().isAfter(nextPaymentDate);
//       } else if (paymentDateStr != null && paymentDateStr.isNotEmpty) {
//         final DateTime paymentDate = DateTime.parse(paymentDateStr);
//         return DateTime.now().difference(paymentDate).inDays > 30;
//       }
//     }
//     print("No valid completed payment found.");
//     return true;
//   } catch (e) {
//     print("Error checking payment expiration: $e");
//     return true;
//   }
// }
//
// Future<void> sendEmailWithIp() async {
//   try {
//     final DateTime now = DateTime.now();
//     final String formattedDate = '${now.toLocal()}';
//
//     // Get public IP
//     final response = await http.get(Uri.parse('https://api.ipify.org?format=json'));
//     if (response.statusCode != 200) {
//       print('Failed to fetch IP address');
//       return;
//     }
//     final ipData = jsonDecode(response.body);
//     String ipAddress = ipData['ip'];
//
//     // Get location from IP
//     final locationResponse = await http.get(Uri.parse('https://ipinfo.io/$ipAddress/json'));
//     String location = 'Location not available';
//     String city = '', region = '', country = '', loc = '', mapLink = 'Unavailable';
//
//     if (locationResponse.statusCode == 200) {
//       final locationData = jsonDecode(locationResponse.body);
//       city = locationData['city'] ?? 'Unknown City';
//       region = locationData['region'] ?? 'Unknown Region';
//       country = locationData['country'] ?? 'Unknown Country';
//       loc = locationData['loc'] ?? '';
//       location = '$city, $region, $country (Coordinates: $loc)';
//       mapLink = loc.isNotEmpty
//           ? 'https://www.google.com/maps/search/?api=1&query=$loc'
//           : 'Unavailable';
//     }
//
//     // Get device info
//     final deviceInfo = DeviceInfoPlugin();
//     String deviceDetails = '', macAddress = 'MAC not available';
//     if (Platform.isWindows) {
//       final windowsInfo = await deviceInfo.windowsInfo;
//       deviceDetails = '''
//           <ul>
//             <li><strong>OS:</strong> Windows</li>
//             <li><strong>Computer Name:</strong> ${windowsInfo.computerName}</li>
//             <li><strong>User Name:</strong> ${windowsInfo.userName}</li>
//             <li><strong>CPU Cores:</strong> ${windowsInfo.numberOfCores}</li>
//             <li><strong>RAM:</strong> ${windowsInfo.systemMemoryInMegabytes} MB</li>
//           </ul>
//           ''';
//       macAddress = await getWindowsMacAddress();
//     } else {
//       deviceDetails = '<p><em>Platform not supported</em></p>';
//     }
//
//     // Get business name from DB
//     String businessName = 'STOCK&INVENTORY SOFTWARE';
//     final dbPath = 'C:\\Users\\Public\\epharmacy\\epharmacy.db';
//     final db = await openDatabase(dbPath);
//     final businessResult = await db.rawQuery('SELECT business_name FROM businesses LIMIT 1');
//     if (businessResult.isNotEmpty) {
//       final name = businessResult[0]['business_name'];
//       if (name != null && name.toString().trim().isNotEmpty) {
//         businessName = name.toString().trim();
//       }
//     }
//
//     // Email configuration
//     final smtpServer = SmtpServer(
//       'mail.ephamarcysoftware.co.tz',
//       username: 'suport@ephamarcysoftware.co.tz',
//       password: 'Matundu@2050',
//       port: 465,
//       ssl: true,
//     );
//
//     final htmlContent = '''
//         <html>
//         <head>
//           <style>
//             body { font-family: Arial, sans-serif; color: #333; }
//             h2 { color: #007BFF; }
//             p { line-height: 1.5; }
//             .section { margin-bottom: 20px; }
//             .label { font-weight: bold; }
//             .footer { font-size: 12px; color: #888; margin-top: 40px; }
//           </style>
//         </head>
//         <body>
//           <h2>🚨 $businessName Installation Alert</h2>
//           <div class="section">
//             <p><span class="label">📅 Date Installed:</span> $formattedDate</p>
//             <p><span class="label">🌐 IP Address:</span> $ipAddress</p>
//             <p><span class="label">📍 Location:</span> $location</p>
//             <p><span class="label">🗺️ View on Map:</span> <a href="$mapLink">Google Maps</a></p>
//             <p><span class="label">🔗 MAC Address:</span> $macAddress</p>
//           </div>
//           <div class="section">
//             <h3>🖥️ Device Information</h3>
//             $deviceDetails
//           </div>
//           <div class="footer">
//             This is an automated notification from the $businessName System.
//           </div>
//         </body>
//         </html>
//         ''';
//
//     final message = mailer.Message()
//       ..from = mailer.Address('suport@ephamarcysoftware.co.tz', businessName)
//       ..recipients.add('ephamarcysoftwares@gmail.com')
//       ..subject = 'Installation Alert - $businessName'
//       ..html = htmlContent;
//
//     final sendReport =  await mailer.send(message, smtpServer);
//     print('Email sent: $sendReport');
//   } catch (e) {
//     print('Error sending installation email: $e');
//   }
// }