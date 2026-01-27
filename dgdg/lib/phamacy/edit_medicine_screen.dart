import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';  // Import for database operations

class EditMedicineScreen extends StatefulWidget {
  final int id;
  final String name;
  final String company;
  final double price;
  final int remaining_quantity;
  final String manufacturedDate;
  final String expiryDate;

  const EditMedicineScreen({
    super.key,
    required this.id,
    required this.name,
    required this.company,
    required this.price,
    required this.remaining_quantity,
    required this.manufacturedDate,
    required this.expiryDate,
  });

  @override
  _EditMedicineScreenState createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  late TextEditingController nameController;
  late TextEditingController companyController;
  late TextEditingController priceController;
  late TextEditingController quantityController;
  late TextEditingController manufacturedDateController;
  late TextEditingController expiryDateController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name);
    companyController = TextEditingController(text: widget.company);
    priceController = TextEditingController(text: widget.price.toString());
    quantityController = TextEditingController(text: widget.remaining_quantity.toString());
    manufacturedDateController = TextEditingController(text: widget.manufacturedDate);
    expiryDateController = TextEditingController(text: widget.expiryDate);
  }

  @override
  void dispose() {
    nameController.dispose();
    companyController.dispose();
    priceController.dispose();
    quantityController.dispose();
    manufacturedDateController.dispose();
    expiryDateController.dispose();
    super.dispose();
  }

  // Function to show date picker and set the selected date to controller
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.toLocal()}".split(' ')[0]; // Format: YYYY-MM-DD
      });
    }
  }

  // Function to validate if the expiry date is before the current date
  bool _isExpiryDateValid(String expiryDate) {
    DateTime currentDate = DateTime.now();
    DateTime expiry = DateFormat("yyyy-MM-dd").parse(expiryDate);
    return expiry.isAfter(currentDate); // Returns true if expiry date is after current date
  }

  Future<void> updateMedicine() async {
    // Check if the expiry date is valid
    if (!_isExpiryDateValid(expiryDateController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expiry date cannot be in the past.')));
      return;
    }

    // Parse the quantity with a fallback to 0 if invalid or empty
    int remainingQuantity = (quantityController.text.isEmpty || int.tryParse(quantityController.text) == null)
        ? 0
        : int.parse(quantityController.text);

    // Prepare the medicine data with the correct value for remaining_quantity
    Map<String, dynamic> medicine = {
      'id': widget.id,
      'name': nameController.text,
      'company': companyController.text,
      'price': double.tryParse(priceController.text) ?? 0.0,
      'remaining_quantity': remainingQuantity,  // Use the parsed value
      'manufacture_date': manufacturedDateController.text,
      'expiry_date': expiryDateController.text,
    };

    // Debug: Check the values before updating
    print('Medicine to update: $medicine');
    // Debug: Print the SQL query and parameters *after* fixing null
    print('Executing update query with parameters:');
    print('Name: ${medicine['name']}');
    print('Company: ${medicine['company']}');
    print('Price: ${medicine['price']}');
    print('Remaining Quantity: ${medicine['remaining_quantity']}'); // will show 0 if fixed
    print('Manufacture Date: ${medicine['manufacture_date']}');
    print('Expiry Date: ${medicine['expiry_date']}');
    print('ID: ${medicine['id']}');

    // Save to the database
    await DatabaseHelper.instance.updateMedicine(medicine);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product updated successfully!')));

    // Navigate back to the previous screen
    Navigator.pop(context, true);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Edit Product",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(nameController, 'Product Name', Icons.medication),
              _buildTextField(companyController, 'Company', Icons.business),
              _buildTextField(priceController, 'Price', Icons.monetization_on, inputType: TextInputType.number),
              _buildTextField(quantityController, 'Remaining Quantity', Icons.add_shopping_cart, inputType: TextInputType.number),
              _buildDateField(manufacturedDateController, 'Manufactured Date'),
              _buildDateField(expiryDateController, 'Expiry Date'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: updateMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                  textStyle: TextStyle(fontSize: 18),
                ),
                child: Text('Update Product', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 30),
              _buildMedicineDetailsTable(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  // Custom widget to build a text field with an icon and label
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green, width: 2)),
        ),
      ),
    );
  }

  // Custom widget to build date fields (Manufactured Date, Expiry Date)
  Widget _buildDateField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: () => _selectDate(context, controller),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_today, color: Colors.green),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green, width: 2)),
        ),
      ),
    );
  }

  // Function to display the table with the medicine details
  Widget _buildMedicineDetailsTable() {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Product Name')),
        DataColumn(label: Text('Company')),
        DataColumn(label: Text('Price')),
        DataColumn(label: Text('Remaining Quantity')),
      ],
      rows: [
        DataRow(cells: [
          DataCell(Text(nameController.text)),
          DataCell(Text(companyController.text)),
          DataCell(Text(priceController.text)),
          DataCell(Text(quantityController.text)),
        ]),
      ],
    );
  }
}
