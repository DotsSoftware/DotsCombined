import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter_pdfview/flutter_pdfview.dart'; // Add this import

class InvoicesDatabasePage extends StatefulWidget {
  @override
  _InvoicesDatabasePageState createState() => _InvoicesDatabasePageState();
}

class _InvoicesDatabasePageState extends State<InvoicesDatabasePage> {
  String filter = 'All';
  late String currentUserEmail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUserEmail();
  }

  void _getCurrentUserEmail() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        currentUserEmail = user.email!;
      });
    }
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

  Future<File> generateInvoicePdf(Map<String, dynamic> transaction) async {
    final pdf = pw.Document();

    final imageUrl =
        'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca';
    final response = await http.get(Uri.parse(imageUrl));
    final image = pw.MemoryImage(response.bodyBytes);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(image, width: 100, height: 100),
                pw.Text(
                  'DOTS INVOICE',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Invoice #${transaction['id']}',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Invoice Date: ${transaction['timestamp'].toDate().toLocal().toString().split(' ')[0]}',
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Due Date: ${transaction['timestamp'].toDate().add(Duration(days: 7)).toLocal().toString().split(' ')[0]}',
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Amount: R${transaction['amount'].toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Status: ${transaction['status']}'),
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
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('invoices')
        .child('invoice_$transactionId.pdf');
    final uploadTask = storageRef.putFile(pdfFile);
    final taskSnapshot = await uploadTask.whenComplete(() => null);
    final downloadUrl = await taskSnapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> _openOrGeneratePdf(Map<String, dynamic> transaction) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoice_${transaction['id']}.pdf');

      if (await file.exists()) {
        setState(() {
          _isLoading = false;
        });
        _showOpenOrGenerateDialog(transaction, file);
      } else {
        await _generateAndOpenPdf(transaction);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generateAndOpenPdf(Map<String, dynamic> transaction) async {
    final file = await generateInvoicePdf(transaction);
    final downloadUrl = await uploadPdfToFirestore(file, transaction['id']);
    _openPdf(file.path); // Updated to use _openPdf
    _showStorePdfDialog(file);
    _savePdfUrlToFirestore(transaction['id'], downloadUrl);
  }

  void _showOpenOrGenerateDialog(
    Map<String, dynamic> transaction,
    File existingFile,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invoice PDF'),
        content: Text(
          'Do you want to open the existing PDF or generate a new one?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openPdf(existingFile.path); // Updated to use _openPdf
              _showStorePdfDialog(existingFile);
            },
            child: Text('Open'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _generateAndOpenPdf(transaction);
            },
            child: Text('Generate New'),
          ),
        ],
      ),
    );
  }

  void _showStorePdfDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Store Invoice PDF'),
        content: Text(
          'Do you want to store the generated invoice PDF on your device?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _storePdfOnDevice(file);
            },
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _storePdfOnDevice(File file) async {
    final directory = await getExternalStorageDirectory();
    final newPath = '${directory!.path}/invoice_${file.path.split('/').last}';
    final newFile = await file.copy(newPath);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice PDF stored at ${newFile.path}')),
    );
  }

  Future<void> _savePdfUrlToFirestore(
    String transactionId,
    String pdfUrl,
  ) async {
    await FirebaseFirestore.instance
        .collection('consultant_side')
        .doc(transactionId)
        .update({'pdfUrl': pdfUrl});
  }

  void _openPdf(String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerPage(filePath: filePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Invoices',
          style: TextStyle(color: Color.fromARGB(225, 0, 74, 173)),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('consultant_side')
                      .where('userEmail', isEqualTo: currentUserEmail)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    var transactions = snapshot.data!.docs;
                    if (filter != 'All') {
                      transactions = transactions
                          .where((doc) => doc['status'] == filter)
                          .toList();
                    }
                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        var transaction = transactions[index];
                        String shortenedId = transaction.id.substring(0, 8);
                        return Card(
                          color: Color.fromARGB(225, 0, 74, 173),
                          margin: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: ListTile(
                            onTap: () {
                              _openOrGeneratePdf(
                                transaction.data() as Map<String, dynamic>,
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(
                                transaction['status'],
                              ),
                              child: Icon(
                                _getStatusIcon(transaction['status']),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              'Transaction: $shortenedId',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Amount: R${transaction['amount'].toStringAsFixed(2)}',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  'Status: ${transaction['status']}',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.picture_as_pdf),
                              onPressed: () => _openOrGeneratePdf(
                                transaction.data() as Map<String, dynamic>,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 10),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All'),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Paid',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hourglass_empty),
            label: 'Unpaid',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.cancel), label: 'Cancelled'),
          BottomNavigationBarItem(
            icon: Icon(Icons.money_off),
            label: 'Refunded',
          ),
        ],
        selectedItemColor: Color.fromARGB(225, 0, 74, 173),
        unselectedItemColor: Color.fromARGB(225, 0, 74, 173),
        onTap: (index) {
          setState(() {
            switch (index) {
              case 0:
                filter = 'All';
                break;
              case 1:
                filter = 'Paid';
                break;
              case 2:
                filter = 'Unpaid';
                break;
              case 3:
                filter = 'Cancelled';
                break;
              case 4:
                filter = 'Refunded';
                break;
            }
          });
        },
        currentIndex: [
          'All',
          'Paid',
          'Unpaid',
          'Cancelled',
          'Refunded',
        ].indexOf(filter),
      ),
    );
  }
}

class PdfViewerPage extends StatelessWidget {
  final String filePath;

  PdfViewerPage({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Invoice PDF')),
      body: PDFView(filePath: filePath),
    );
  }
}
