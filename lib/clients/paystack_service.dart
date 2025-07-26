import 'dart:convert';
import 'package:http/http.dart' as http;

class PaystackService {
  final String secretKey;
  final String publicKey;

  PaystackService({required this.secretKey, required this.publicKey});

  Future<String?> initializeTransaction(int amount, String email) async {
    final url = Uri.parse('https://api.paystack.co/transaction/initialize');
    final headers = {
      'Authorization': 'Bearer $secretKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
      'amount': amount,
    });

    final response = await http.post(url, headers: headers, body: body);
    print(
        'Paystack initializeTransaction response status: ${response.statusCode}');
    print('Paystack initializeTransaction response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['data']['access_code'] != null) {
        return data['data']['access_code'];
      } else {
        // Generate an access code manually if not provided
        return await _generateAccessCode(amount, email);
      }
    } else {
      throw Exception('Failed to initialize transaction');
    }
  }

  Future<String?> _generateAccessCode(int amount, String email) async {
    final url = Uri.parse('https://api.paystack.co/transaction/initialize');
    final headers = {
      'Authorization': 'Bearer $secretKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
      'amount': amount,
      'reference':
          'unique_reference_here', // Ensure this is unique for each transaction
    });

    final response = await http.post(url, headers: headers, body: body);
    print(
        'Paystack generateAccessCode response status: ${response.statusCode}');
    print('Paystack generateAccessCode response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['access_code'];
    } else {
      throw Exception('Failed to generate access code');
    }
  }

  Future<bool> verifyTransaction(String reference) async {
    final url =
        Uri.parse('https://api.paystack.co/transaction/verify/$reference');
    final headers = {
      'Authorization': 'Bearer $secretKey',
    };

    final response = await http.get(url, headers: headers);
    print('Paystack verifyTransaction response status: ${response.statusCode}');
    print('Paystack verifyTransaction response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['status'] == 'success';
    } else {
      throw Exception('Failed to verify transaction');
    }
  }
}
