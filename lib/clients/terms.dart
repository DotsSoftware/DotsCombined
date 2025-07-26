import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dashboard.dart';
import 'dart:math' show min, max;

import 'phone_verification.dart';

class TermsPage extends StatefulWidget {
  const TermsPage({Key? key}) : super(key: key);

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  final GlobalKey<SfSignaturePadState> _signaturePadKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _hasReachedEnd = false;
  bool _hasSigned = false;
  bool _isSignatureValid = false;
  List<Offset> _signaturePoints = [];
  final double _minSignatureSize = 50.0;
  int _totalPages = 0;
  int _currentPage = 1;
  bool _isSubmitting = false;
  // Signature points to track drawing

  Widget _title() {
    return const Text(
      'DOTS',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(225, 0, 74, 173),
        fontFamily: 'Quicksand',
      ),
    );
  }

  Widget _appBarImage() {
    return Image.network(
      'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
      height: 55,
      width: 55,
      errorBuilder:
          (BuildContext context, Object exception, StackTrace? stackTrace) {
        return const Text('Image not found');
      },
    );
  }

  Widget _buildPdfViewer() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      child: SfPdfViewer.network(
        'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/GENERAL%20TERMS%20AND%20CONDITIONS%20-%20Clients.pdf?alt=media&token=11f8ac64-71b5-4e00-84a9-0cf02ebf0967',
        controller: _pdfViewerController,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
        },
        onPageChanged: (PdfPageChangedDetails details) {
          setState(() {
            _currentPage = details.newPageNumber;
            _hasReachedEnd = details.newPageNumber == _totalPages;
          });
        },
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _currentPage > 1
              ? () {
                  _pdfViewerController.previousPage();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text('Previous', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 20),
        Text('Page $_currentPage of $_totalPages'),
        const SizedBox(width: 20),
        ElevatedButton(
          onPressed: _currentPage < _totalPages
              ? () {
                  _pdfViewerController.nextPage();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text('Next', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  bool _handleSignatureStart() {
    _signaturePoints.clear();
    setState(() {
      _isSignatureValid = false;
      _hasSigned = false;
    });
    return true; // Return true to allow drawing
  }

  void _handleSignatureDraw(Offset point, DateTime timestamp) {
    _signaturePoints.add(point);

    if (_signaturePoints.length < 10) return;

    double minX = _signaturePoints.map((p) => p.dx).reduce(min);
    double maxX = _signaturePoints.map((p) => p.dx).reduce(max);
    double minY = _signaturePoints.map((p) => p.dy).reduce(min);
    double maxY = _signaturePoints.map((p) => p.dy).reduce(max);

    double width = maxX - minX;
    double height = maxY - minY;

    bool isValid = width > _minSignatureSize && height > _minSignatureSize;

    if (isValid && !_isSignatureValid) {
      setState(() {
        _isSignatureValid = true;
        _hasSigned = true;
      });
    }
  }

  void _handleSignatureEnd() {
    // Optional: Add any end-of-signature logic here
  }

  Widget _buildSignaturePad() {
    return _hasReachedEnd
        ? Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Please sign below to accept the terms and conditions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SfSignaturePad(
                  key: _signaturePadKey,
                  backgroundColor: Colors.white,
                  strokeColor: Colors.black,
                  minimumStrokeWidth: 1.0,
                  maximumStrokeWidth: 4.0,
                  onDrawStart: _handleSignatureStart,
                  onDraw: _handleSignatureDraw,
                  onDrawEnd: _handleSignatureEnd,
                ),
              ),
              if (_isSignatureValid)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Signature captured',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _signaturePadKey.currentState?.clear();
                  _handleSignatureStart();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Clear Signature',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          )
        : const SizedBox.shrink();
  }

  bool _validateSignaturePoint(Offset point) {
    _signaturePoints.add(point);

    if (_signaturePoints.length < 10) return false;

    double minX = _signaturePoints.map((p) => p.dx).reduce(min);
    double maxX = _signaturePoints.map((p) => p.dx).reduce(max);
    double minY = _signaturePoints.map((p) => p.dy).reduce(min);
    double maxY = _signaturePoints.map((p) => p.dy).reduce(max);

    double width = maxX - minX;
    double height = maxY - minY;

    bool isValid = width > _minSignatureSize && height > _minSignatureSize;

    if (isValid && !_isSignatureValid) {
      setState(() {
        _isSignatureValid = true;
        _hasSigned = true;
      });
    }

    return isValid;
  }

  Future<void> _saveSignatureToFirestore() async {
    if (!_isSignatureValid) return;

    try {
      setState(() => _isSubmitting = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Convert signature to image
      final signatureData = await _signaturePadKey.currentState?.toImage();
      final bytes =
          await signatureData?.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('Failed to get signature data');

      // Upload signature to Storage
      final storage = FirebaseStorage.instance;
      final signatureRef = storage.ref().child(
          'signatures/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.png');
      await signatureRef.putData(bytes.buffer.asUint8List());
      final signatureUrl = await signatureRef.getDownloadURL();

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'termsAccepted': true,
        'termsAcceptanceDate': FieldValue.serverTimestamp(),
        'signatureUrl': signatureUrl,
        'termsVersion': '1.0',
      }, SetOptions(merge: true));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PhoneVerificationPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving signature: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _submitButton() {
    return _hasReachedEnd && _isSignatureValid
        ? Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _saveSignatureToFirestore,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                backgroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Accept and Continue',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          )
        : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            _appBarImage(),
            const SizedBox(width: 10),
            _title(),
          ],
        ),
        toolbarHeight: 72,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Terms and Conditions',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(225, 0, 74, 173),
                  fontFamily: 'Quicksand',
                ),
              ),
              const SizedBox(height: 20),
              _buildPdfViewer(),
              const SizedBox(height: 20),
              _buildNavigationButtons(),
              _buildSignaturePad(),
              _submitButton(),
            ],
          ),
        ),
      ),
    );
  }
}
