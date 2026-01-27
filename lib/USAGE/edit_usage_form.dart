import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../DB/database_helper.dart';

class EditUsageForm extends StatefulWidget {
  final int usageId;
  final int userId;
  final String addedBy;
  final String initialCategory;
  final String? initialDescription;
  final double initialAmount;

  EditUsageForm({
    required this.usageId,
    required this.userId,
    required this.addedBy,
    required this.initialCategory,
    this.initialDescription,
    required this.initialAmount,
  });

  @override
  _EditUsageFormState createState() => _EditUsageFormState();
}

class _EditUsageFormState extends State<EditUsageForm> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedCategory;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final List<String> _categories = ['Food', 'Electricity', 'Water', 'Other'];

  bool get _showDescriptionField => _selectedCategory == 'Other';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _descriptionController.text = widget.initialDescription ?? '';
    _amountController.text = widget.initialAmount.toString();
  }

  void _updateUsage() async {
    if (_formKey.currentState!.validate()) {
      final db = await DatabaseHelper.instance.database;

      await db.update(
        'normal_usage',
        {
          'category': _selectedCategory,
          'description': _showDescriptionField ? _descriptionController.text : null,
          'amount': double.tryParse(_amountController.text) ?? 0.0,
        },
        where: 'id = ?',
        whereArgs: [widget.usageId],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usage data updated successfully!')),
      );

      Navigator.pop(context); // Close the edit screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Usage',style: const TextStyle(color: Colors.white),),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(labelText: 'Category'),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
                validator: (value) =>
                value == null ? 'Please select a category' : null,
              ),
              if (_showDescriptionField)
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter a description'
                      : null,
                ),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Amount (TSH)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateUsage,
                child: Text('Update Usage'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
