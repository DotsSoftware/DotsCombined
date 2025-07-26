import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'payment_failed_page.dart';
import 'payment_successful_page.dart';
import 'paystack_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaystackWebView extends StatefulWidget {
  final String accessCode;
  final PaystackService paystackService;
  final double totalPrice;
  final String email;

  PaystackWebView({
    required this.accessCode,
    required this.paystackService,
    required this.totalPrice,
    required this.email,
  });

  @override
  _PaystackWebViewState createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<PaystackWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) async {
          if (request.url.contains('https://standard.paystack.co/close')) {
            final reference = Uri.parse(request.url).queryParameters['trxref'];
            if (reference != null) {
              final isSuccess =
                  await widget.paystackService.verifyTransaction(reference);
              if (isSuccess) {
                await FirebaseFirestore.instance
                    .collection('transactions')
                    .add({
                  'email': widget.email,
                  'amount': widget.totalPrice,
                  'status': 'success',
                  'transaction_reference': reference,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentSuccessfulPage(),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentFailedPage(),
                  ),
                );
              }
            }
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(
          Uri.parse('https://standard.paystack.co/pay/${widget.accessCode}'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paystack Payment'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
