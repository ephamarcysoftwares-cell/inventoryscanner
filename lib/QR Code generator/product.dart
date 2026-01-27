class Product {
  final String productName;
  final String businessName;
  final String category;
  final String phoneNumber;
  final String email;
  final String kg;
  final String productId;

  Product({
    required this.productName,
    required this.businessName,
    required this.category,
    required this.phoneNumber,
    required this.email,
    required this.kg,
    required this.productId,
  });

  // Convert product data into a map format for Firestore
  Map<String, dynamic> toMap() {
    return {
      "productName": productName,
      "businessName": businessName,
      "category": category,
      "phoneNumber": phoneNumber,
      "email": email,
      "kg": kg,
    };
  }

  // Factory method to create Product from Firestore data
  factory Product.fromMap(Map<String, dynamic> data, String productId) {
    return Product(
      productName: data['productName']['stringValue'],
      businessName: data['businessName']['stringValue'],
      category: data['category']['stringValue'],
      phoneNumber: data['phoneNumber']['stringValue'],
      email: data['email']['stringValue'],
      kg: data['kg']['stringValue'],
      productId: productId,
    );
  }
}
