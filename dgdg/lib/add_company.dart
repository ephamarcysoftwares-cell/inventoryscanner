import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddCompanyScreen extends StatefulWidget {
  const AddCompanyScreen({super.key});

  @override
  _AddCompanyScreenState createState() => _AddCompanyScreenState();
}

class _AddCompanyScreenState extends State<AddCompanyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isLoading = false;

  /// 🔥 Helper to get the current business owner's name
  Future<String?> _getCurrentBusinessName() async {
    try {
      final data = await Supabase.instance.client
          .from('businesses')
          .select('business_name')
          .limit(1)
          .maybeSingle();
      return data?['business_name'];
    } catch (e) {
      debugPrint("Error fetching business name: $e");
      return null;
    }
  }

  Future<void> _addCompany() async {
    setState(() => _isLoading = true);

    String companyName = _nameController.text.trim();
    String address = _addressController.text.trim();

    // 1. Validation
    if (companyName.isEmpty || address.isEmpty) {
      _showSnackBar("Please fill all fields", Colors.orange);
      setState(() => _isLoading = false);
      return;
    }

    // 2. Connectivity Check
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showSnackBar("No internet connection!", Colors.red);
      setState(() => _isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // 3. Get the active business name to associate with this company
      String? myBizName = await _getCurrentBusinessName();

      if (myBizName == null) {
        _showSnackBar("Business profile not found. Please set up business first.", Colors.red);
        return;
      }

      // 4. Check for duplicates in Supabase for this specific business
      final existing = await supabase
          .from('companies')
          .select()
          .eq('name', companyName)
          .eq('business_name', myBizName)
          .maybeSingle();

      if (existing != null) {
        _showSnackBar("Company already exists under your business", Colors.blue);
        return;
      }

      // 5. Insert into Supabase
      await supabase.from('companies').insert({
        'name': companyName,
        'address': address,
        'business_name': myBizName, // ✅ Associated from your businesses table
      });

      _nameController.clear();
      _addressController.clear();
      _showSnackBar("Company added successfully!", Colors.green);

    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Company", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildTextField(controller: _nameController, label: "Company Name", icon: Icons.business),
              _buildTextField(controller: _addressController, label: "Company Address", icon: Icons.location_on),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _addCompany,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF388E3C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("SAVE TO CLOUD", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.teal),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }
}