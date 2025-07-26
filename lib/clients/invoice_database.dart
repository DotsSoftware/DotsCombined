import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart'; // Updated for sharing
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient
import 'login_register_page.dart';
import 'continue.dart'; // Assuming ContinuePage is the navigation target

class InvoicesDatabasePage extends StatefulWidget {
  const InvoicesDatabasePage({Key? key}) : super(key: key);

  @override
  _InvoicesDatabasePageState createState() => _InvoicesDatabasePageState();
}

class _InvoicesDatabasePageState extends State<InvoicesDatabasePage>
    with TickerProviderStateMixin {
  String filter = 'All';
  String? currentUserEmail;
  bool _isLoading = true;
  String? errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  static const Map<String, String> competencyPrices = {
    'Level 1 - Basic Knowledge': '500.00',
    'Level 2 - Skilled In Industry': '937.50',
    'Level 3 - High Level Of Expertise': '2187.50',
  };

  static const Map<String, String> publicTransportPrices = {
    'Local - Within a 50km Radius': '187.50',
    'Regional - Within a 300km Radius': '475.00',
    'National - Within a 1500km Radius': '6250.50',
  };

  static const Map<String, String> ownVehiclePrices = {
    'Local - Within a 50km Radius': '437.50',
    'Regional - Within a 300km Radius': '1450.00',
    'Provincial - Within a 500km Radius': '1950.00',
    'Interprovincial - Within a 1000km Radius': '3106.25',
    'National - Within a 1500km Radius': '10937.50',
  };

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _getCurrentUserEmail();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserEmail() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = 'Please sign in to view invoices';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to view invoices'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        setState(() {
          currentUserEmail = user.email!;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error initializing user: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing user: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getCompetencyPrice(String? competencyType) {
    return competencyPrices[competencyType] ?? '0.00';
  }

  String _getDistancePrice(String? distanceType) {
    return publicTransportPrices[distanceType] ??
        ownVehiclePrices[distanceType] ??
        '0.00';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Paid':
        return Icons.check_circle;
      case 'Unpaid':
        return Icons.hourglass_empty;
      case 'Cancelled':
        return Icons.cancel;
      case 'Refunded':
        return Icons.money_off;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Unpaid':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      case 'Refunded':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<Map<String, dynamic>> _fetchTransactionDetails(
    String userEmail,
    Timestamp timestamp,
  ) async {
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .get();

      if (userQuery.docs.isEmpty) return {};

      final userId = userQuery.docs.first.id;
      final transactionQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('timestamp', isEqualTo: timestamp)
          .get();

      if (transactionQuery.docs.isEmpty) return {};

      final integratedDoc = await FirebaseFirestore.instance
          .collection('integrated')
          .doc(userEmail)
          .get();

      final selectionQuery = await FirebaseFirestore.instance
          .collection('selection')
          .doc(userId)
          .collection('requests')
          .where('timestamp', isEqualTo: timestamp)
          .get();

      Map<String, dynamic> transactionData = transactionQuery.docs.first.data();

      if (integratedDoc.exists) {
        final appointments = List.from(
          integratedDoc.data()?['appointments'] ?? [],
        );
        final matchingAppointment = appointments.firstWhere(
          (appointment) =>
              (appointment['timestamp'] as Timestamp?)?.toDate() ==
              timestamp.toDate(),
          orElse: () => {},
        );

        if (matchingAppointment.isNotEmpty) {
          transactionData['selected_distance'] =
              matchingAppointment['selected_distance'];
        }
      }

      if (selectionQuery.docs.isNotEmpty) {
        transactionData['selected_type'] = selectionQuery.docs.first
            .data()['selected_type'];
      }

      return transactionData;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching transaction details: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchAdditionalData(
    String userEmail,
    Timestamp timestamp,
  ) async {
    try {
      final registerSnapshot = await FirebaseFirestore.instance
          .collection('register')
          .where('email', isEqualTo: userEmail)
          .get();

      final userId = FirebaseAuth.instance.currentUser?.uid;
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('selection')
          .doc(userId)
          .collection('requests')
          .where('timestamp', isEqualTo: timestamp)
          .get();

      final integratedDoc = await FirebaseFirestore.instance
          .collection('integrated')
          .doc(userEmail)
          .get();

      Map<String, dynamic> data = {
        'register': registerSnapshot.docs.isNotEmpty
            ? registerSnapshot.docs.first.data()
            : {},
        'requests': requestsSnapshot.docs.isNotEmpty
            ? requestsSnapshot.docs.first.data()
            : {},
        'appointments': {},
      };

      if (integratedDoc.exists) {
        final appointments = List.from(
          integratedDoc.data()?['appointments'] ?? [],
        );
        final matchingAppointment = appointments.firstWhere(
          (appointment) =>
              (appointment['timestamp'] as Timestamp?)?.toDate() ==
              timestamp.toDate(),
          orElse: () => {},
        );

        if (matchingAppointment.isNotEmpty) {
          data['appointments'] = matchingAppointment;
        }
      }

      return data;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching additional data: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return {};
    }
  }

  Future<String> _getNextInvoiceId() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('invoiceCounter');
    try {
      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final snapshot = await transaction.get(counterRef);
        int newCount = 1;
        if (snapshot.exists) {
          final currentCount = snapshot['count'] as int? ?? 0;
          newCount = currentCount + 1;
        }
        transaction.set(counterRef, {'count': newCount});
        return newCount.toString().padLeft(3, '0');
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating invoice ID: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return '000';
    }
  }

  Future<File> generateInvoicePdf(
    Map<String, dynamic> transaction,
    Map<String, dynamic> additionalData,
  ) async {
    final pdf = pw.Document();
    pw.MemoryImage? image;
    try {
      const imageUrl =
          'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9878-39c6c248f5ca';
      final response = await http.get(Uri.parse(imageUrl));
      image = pw.MemoryImage(response.bodyBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading logo: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final transactionDetails = await _fetchTransactionDetails(
      currentUserEmail!,
      transaction['timestamp'] as Timestamp,
    );
    final competencyPrice =
        double.tryParse(
          _getCompetencyPrice(transactionDetails['selected_type']),
        ) ??
        0.0;
    final distancePrice =
        double.tryParse(
          _getDistancePrice(transactionDetails['selected_distance']),
        ) ??
        0.0;
    final subtotal = competencyPrice + distancePrice;
    final vat = subtotal * 0.15;
    final total = subtotal + vat;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (image != null) pw.Image(image, width: 100, height: 100),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'DOTS SOFTWARE',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Eco Fusion Office Park',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      '300 Witch-Hazel Ave',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Highveld, Centurion',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text('0157', style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Invoice #${transaction['id']}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Date: ${(transaction['timestamp'] as Timestamp).toDate().toString().split('.')[0]}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            if (additionalData['register'].isNotEmpty) ...[
              pw.Text(
                'Invoiced To:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Name: ${additionalData['register']['firstName'] ?? 'N/A'} ${additionalData['register']['surname'] ?? ''}',
              ),
              pw.Text('Email: ${additionalData['register']['email'] ?? 'N/A'}'),
              pw.Text(
                'Phone: ${additionalData['register']['phoneNumber'] ?? 'N/A'}',
              ),
              pw.Text(
                'Address: ${additionalData['register']['address'] ?? 'N/A'}',
              ),
              pw.SizedBox(height: 20),
            ],
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Item',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Description',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Amount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('1'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Competency: ${transactionDetails['selected_type'] ?? 'N/A'}',
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('R ${competencyPrice.toStringAsFixed(2)}'),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('2'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Travel: ${transactionDetails['selected_distance'] ?? 'N/A'}',
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('R ${distancePrice.toStringAsFixed(2)}'),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Subtotal: R ${subtotal.toStringAsFixed(2)}'),
                  pw.Text('15% VAT: R ${vat.toStringAsFixed(2)}'),
                  pw.Text(
                    'Total: R ${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/invoice_${transaction['id']}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<String> uploadPdfToFirestore(
    File pdfFile,
    String transactionId,
  ) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('invoices')
          .child('invoice_$transactionId.pdf');
      final uploadTask = storageRef.putFile(pdfFile);
      final taskSnapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      rethrow;
    }
  }

  Future<void> _savePdfUrlToFirestore(
    String transactionId,
    String pdfUrl,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionId)
          .set({'pdfUrl': pdfUrl}, SetOptions(merge: true));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving PDF URL: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openOrGeneratePdf(Map<String, dynamic> transaction) async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoice_${transaction['id']}.pdf');
      if (await file.exists()) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => _buildDialog(
            title: 'Invoice PDF',
            content:
                'Do you want to open the existing PDF or generate a new one?',
            actions: [
              _buildDialogButton('Open', () => true),
              _buildDialogButton('Generate New', () => false),
            ],
          ),
        );
        if (result == true) {
          await _openPdf(file.path);
          await _showStorePdfDialog(file);
        } else if (result == false) {
          await _generateAndOpenPdf(transaction);
        }
      } else {
        await _generateAndOpenPdf(transaction);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAndOpenPdf(Map<String, dynamic> transaction) async {
    try {
      final invoiceId = await _getNextInvoiceId();
      transaction['id'] = invoiceId;
      final additionalData = await _fetchAdditionalData(
        currentUserEmail!,
        transaction['timestamp'] as Timestamp,
      );
      final file = await generateInvoicePdf(transaction, additionalData);
      final downloadUrl = await uploadPdfToFirestore(file, invoiceId);
      await _openPdf(file.path);
      await _showStorePdfDialog(file);
      await _savePdfUrlToFirestore(invoiceId, downloadUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openPdf(String filePath) async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(filePath: filePath),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showStorePdfDialog(File file) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDialog(
        title: 'Store Invoice PDF',
        content:
            'Do you want to store the generated invoice PDF on your device?',
        actions: [
          _buildDialogButton('No', () => false),
          _buildDialogButton('Yes', () => true),
        ],
      ),
    );
    if (result == true) {
      await _storePdfOnDevice(file);
    }
  }

  Future<void> _storePdfOnDevice(File file) async {
    try {
      final directory = await getExternalStorageDirectory();
      final newPath = '${directory!.path}/invoice_${file.path.split('/').last}';
      final newFile = await file.copy(newPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice PDF stored at ${newFile.path}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error storing PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDialog({
    required String title,
    required String content,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A8A),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, bool isSelected) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80), // Added fixed width
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF1E3A8A)
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTransactionCard(DocumentSnapshot transaction, int index) {
    final data = transaction.data() as Map<String, dynamic>;
    final shortenedId = transaction.id.substring(
      0,
      transaction.id.length > 8 ? 8 : transaction.id.length,
    );
    final status = data['status']?.toString() ?? 'Unknown';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

    return SlideTransition(
      position: Tween<Offset>(begin: Offset(0, 0.1 * index), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _animationController,
              curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
            ),
          ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () => _openOrGeneratePdf(data),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(status),
                  child: Icon(_getStatusIcon(status), color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice #$shortenedId',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount: R ${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        'Status: $status',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  onPressed: () => _openOrGeneratePdf(data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || currentUserEmail == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: appGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading Invoices...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.network(
                            'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFF1E3A8A),
                                  size: 30,
                                ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Invoices',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Error Message
              if (errorMessage != null)
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Filter Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: ['All', 'Paid', 'Unpaid', 'Cancelled', 'Refunded']
                      .map(
                        (label) => GestureDetector(
                          onTap: () => setState(() => filter = label),
                          child: _buildFilterButton(label, filter == label),
                        ),
                      )
                      .toList(),
                ),
              ),

              // Transaction List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where(
                        'clientEmail',
                        isEqualTo: currentUserEmail,
                      ) // Changed from userEmail to clientEmail
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading Invoices...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading invoices: ${snapshot.error}',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDialogButton('Retry', () => setState(() {})),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No invoices found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort transactions by timestamp manually
                    var transactions = snapshot.data!.docs;
                    transactions.sort((a, b) {
                      Timestamp? aTime = a['timestamp'] as Timestamp?;
                      Timestamp? bTime = b['timestamp'] as Timestamp?;
                      return (bTime ?? Timestamp.now()).compareTo(
                        aTime ?? Timestamp.now(),
                      );
                    });

                    // Apply filter
                    final filteredTransactions = transactions
                        .where(
                          (doc) => filter == 'All' || doc['status'] == filter,
                        )
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) => _buildTransactionCard(
                        filteredTransactions[index],
                        index,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PdfViewerPage extends StatelessWidget {
  final String filePath;

  const PdfViewerPage({Key? key, required this.filePath}) : super(key: key);

  Future<void> _shareFile(BuildContext context) async {
    // Add context as a parameter
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Invoice PDF',
        text: 'Please find the invoice attached',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.network(
                        'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFF1E3A8A),
                              size: 30,
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Invoice PDF',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PDFView(
                  filePath: filePath,
                  onError: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error loading PDF: $error'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () =>
                      _shareFile(context), // Pass context to _shareFile
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Share Invoice',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
