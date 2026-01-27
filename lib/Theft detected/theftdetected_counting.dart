import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Hakikisha hili faili lipo

class CustomerAnalyticsScreen extends StatefulWidget {
  const CustomerAnalyticsScreen({super.key});

  @override
  State<CustomerAnalyticsScreen> createState() => _CustomerAnalyticsScreenState();
}

class _CustomerAnalyticsScreenState extends State<CustomerAnalyticsScreen> {
  // Variable ya kudhibiti scan isijirudie haraka haraka
  bool _isScanning = true;

  // Controller ya Scanner
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  // --- KAZI YA KUVUTA DATA KUTOKA SUPABASE ---
  Future<void> _handleBarcodeDetection(String code) async {
    if (!_isScanning) return; // Kama tayari inashughulikia, tulia

    print("DEBUG: Barcode Imesomwa: $code");

    if (mounted) {
      setState(() => _isScanning = false);
    }

    HapticFeedback.heavyImpact(); // Tetemesha simu

    try {
      print("DEBUG: Inatafuta kwenye database...");

      // Tunatafuta bidhaa kulingana na item_code uliyoscan
      final data = await Supabase.instance.client
          .from('medicines')
          .select()
          .eq('item_code', code.trim())
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        print("DEBUG: Bidhaa Imepatikana: ${data['name']}");

        // Fungua ukurasa wa matokeo (ResultPage)
        // if (mounted) {
        //   Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) => (),
        //     ),
        //   ).then((_) {
        //     // Ukirudi kutoka ResultPage, washa scanner tena
        //     if (mounted) setState(() => _isScanning = true);
        //   });
        // }
      } else {
        print("DEBUG: Kodi $code haipo kwenye database ya medicines.");
        _showErrorSnackBar("Dawa haipo: $code");

        // Subiri sekunde 2 kisha washa scanner tena
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isScanning = true);
        });
      }
    } catch (e) {
      print("DEBUG: ERROR KWENYE SUPABASE: $e");
      _showErrorSnackBar("Tatizo la mtandao au database!");

      if (mounted) setState(() => _isScanning = true);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
            "Scan Barcode", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Kitufe cha kuwasha Flashlight
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Kamera ya Scanner
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && _isScanning) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  _handleBarcodeDetection(code);
                }
              }
            },
          ),

          // 2. Muonekano wa Box la Scanner (Overlay)
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF673AB7), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // 3. Maelekezo kwa mtumiaji
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Weka barcode ndani ya box",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),

          // 4. Loading indicator wakati inatafuta data
          if (!_isScanning)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF673AB7)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // Muhimu kufunga kamera app ikifungwa
    super.dispose();
  }
}
