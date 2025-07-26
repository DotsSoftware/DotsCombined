import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'paystack_service.dart';
import 'paystack_webview.dart';

class PaymentScreen extends StatefulWidget {
  final double totalPrice;

  PaymentScreen({required this.totalPrice});

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final PaystackService _paystackService = PaystackService(
    secretKey: '533bf26278ef55a11c0a603bd19f797fd976c371',
    publicKey:
        '31cfda8f573fd234851364987d58a0dccdb4b3c7', // Replace with your Paystack public key
  );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setUserEmail();
  }

  Future<void> _setUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
    }
  }

  Future<void> _storeTransactionData(String status) async {
    await FirebaseFirestore.instance.collection('transactions').add({
      'userEmail': _emailController.text,
      'amount': widget.totalPrice,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _startPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final amountInKobo =
            (widget.totalPrice * 100).toInt(); // Convert ZAR to Kobo
        final accessCode = await _paystackService.initializeTransaction(
          amountInKobo,
          _emailController.text,
        );

        if (accessCode != null) {
          await _storeTransactionData('Pending');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaystackWebView(
                accessCode: accessCode,
                paystackService: _paystackService,
                totalPrice: widget.totalPrice,
                email: _emailController.text,
              ),
            ),
          );
        }
      } catch (e) {
        print('Error: $e');
        await _storeTransactionData('Unpaid');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: Center(
        child: Container(
          margin: EdgeInsets.all(16.0),
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10.0,
                spreadRadius: 5.0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Image.network(
                        'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/paystack.png?alt=media&token=3c0d74ed-ac3d-405c-bcf4-73ebce6473d8',
                        width: 120.0,
                        height: 100.0,
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Amount Due:',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4.0),
                      Text(
                        'R${widget.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 4.0),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _cardNumberController,
                      decoration: InputDecoration(
                        labelText: 'CARD NUMBER',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter card number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 8.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            decoration: InputDecoration(
                              labelText: 'EXPIRY DATE',
                              hintText: 'MM/YY',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.datetime,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter expiry date';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            decoration: InputDecoration(
                              labelText: 'CVV',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter CVV';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.0),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'EMAIL',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      'We accept',
                      style: TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                    Image.network(
                      'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/icons-removebg-preview.png?alt=media&token=36b24bb4-fe83-4acd-87a9-ad1c85db4954',
                      width: 130.0,
                      height: 100.0,
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _startPayment,
                      child: _isLoading
                          ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color.fromARGB(255, 1, 45, 82)),
                            )
                          : Text('Pay', style: TextStyle(color: Colors.grey)),
                    ),
                    SizedBox(height: 16.0),
                    Icon(Icons.lock, color: Colors.grey, size: 20.0),
                    SizedBox(width: 8.0),
                    Text(
                      'Secured by',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                    Text(
                      'Paystack',
                      style: TextStyle(
                        color: Color.fromARGB(255, 1, 45, 82),
                        fontWeight: FontWeight.bold,
                        fontSize: 17.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
