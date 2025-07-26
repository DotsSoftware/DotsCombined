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
      return data['data']['access_code'];
    } else {
      throw Exception('Failed to initialize transaction');
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
