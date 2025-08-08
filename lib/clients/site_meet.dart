import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'inbox.dart';
import 'dashboard.dart';

class SiteMeetPage extends StatefulWidget {
  @override
  _SiteMeetPageState createState() => _SiteMeetPageState();
}

class _SiteMeetPageState extends State<SiteMeetPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  String? appointmentId;

  // Define TextEditingController for each input field
  final TextEditingController whatToInspectController = TextEditingController();
  final TextEditingController hostDetailsController = TextEditingController();
  final TextEditingController siteNameController = TextEditingController();
  final TextEditingController _controllerJobDate = TextEditingController();
  final TextEditingController _controllerJobTime = TextEditingController();
  final TextEditingController _controllerSiteLocation = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController businessTypeController = TextEditingController();
  final TextEditingController regNoController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController emailAddressController = TextEditingController();
  final TextEditingController physicalAddressController =
      TextEditingController();
  final TextEditingController notesController = TextEditingController();

  CollectionReference siteMeetings =
      FirebaseFirestore.instance.collection('notifications');

  Map<String, Map<String, String>> documentFields = {
    'Document1': {'name': '', 'url': ''},
    'Document2': {'name': '', 'url': ''},
    'Document3': {'name': '', 'url': ''},
    'Document4': {'name': '', 'url': ''},
    'Document5': {'name': '', 'url': ''},
  };

  @override
  void initState() {
    super.initState();
    _fetchLatestAppointmentData();
  }

  Future<void> _fetchLatestAppointmentData() async {
    if (user == null) {
      print('User is not logged in');
      return;
    }

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('selection')
          .doc(user!.uid)
          .collection('appointments')
          .get();

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final appointmentData = doc.data() as Map<String, dynamic>?;

          if (appointmentData != null) {
            print('Fetched appointment data: $appointmentData');

            setState(() {
              _controllerSiteLocation.text =
                  appointmentData['siteLocation'] ?? '';
              _controllerJobDate.text = appointmentData['jobDate'] ?? '';
              _controllerJobTime.text = appointmentData['jobTime'] ?? '';
            });
          }
        }
      } else {
        print('No appointments found for the user.');
      }
    } catch (e) {
      print('Failed to fetch appointment data: $e');
    }
  }

  Future<void> _submitDetails() async {
    try {
      // Create the appointment document first
      DocumentReference docRef = await siteMeetings.add({
        'WhatToInspect': whatToInspectController.text,
        'HostDetails': hostDetailsController.text,
        'SiteName': siteNameController.text,
        'siteLocation': _controllerSiteLocation.text,
        'jobDate': _controllerJobDate.text,
        'jobTime': _controllerJobTime.text,
        'CompanyName': companyNameController.text,
        'BusinessType': businessTypeController.text,
        'RegNo': regNoController.text,
        'ContactPerson': contactPersonController.text,
        'ContactNumber': contactNumberController.text,
        'EmailAddress': emailAddressController.text,
        'PhysicalAddress': physicalAddressController.text,
        'Notes': notesController.text,
        'Documents': documentFields,
        'clientEmail': user?.email,
        'consultantEmail': 'consultant@example.com',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'searching',
        'paymentStatus': 'pending',
      });

      // Store the appointment ID
      appointmentId = docRef.id;

      _showConfirmationDialog();
    } catch (e) {
      print('Error submitting details: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting details. Please try again.')),
      );
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Request Submitted'),
          content: Text('Choose an option'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatInboxPage(), // Navigate to Inbox
                  ),
                );
              },
              child: Text('Chat to consultant'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DashboardPage(), // Navigate to Dashboard
                  ),
                );
              },
              child: Text('Request complete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDocument(String fieldName) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.first.bytes != null) {
        // Create a unique filename using timestamp
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String originalFileName = result.files.first.name;
        String fileExtension = originalFileName.split('.').last;
        String uniqueFileName = '${timestamp}_$originalFileName';

        // Create storage reference
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('appointments')
            .child(user?.email ?? 'anonymous')
            .child(appointmentId ?? DateTime.now().toString())
            .child(uniqueFileName);

        // Upload file
        UploadTask uploadTask = storageRef.putData(result.files.first.bytes!);

        // Get download URL after upload completes
        await uploadTask.whenComplete(() async {
          String downloadUrl = await storageRef.getDownloadURL();

          setState(() {
            documentFields[fieldName] = {
              'name': originalFileName,
              'url': downloadUrl,
            };
          });

          // Update the appointment document with the new document information
          if (appointmentId != null) {
            await siteMeetings.doc(appointmentId).update({
              'Documents': documentFields,
            });
          }
        });
      }
    } catch (e) {
      print('Error uploading document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading document. Please try again.')),
      );
    }
  }

  Widget _buildDocumentField(String fieldName) {
    return GestureDetector(
      onTap: () {
        _pickDocument(fieldName);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.0),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Color.fromARGB(225, 0, 74, 173)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          documentFields[fieldName]?['name'] ?? 'Select Document',
          style: TextStyle(color: Color.fromARGB(225, 0, 74, 173)),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: Color.fromARGB(225, 0, 74, 173)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: Color.fromARGB(225, 0, 74, 173),
              width: 2.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: Color.fromARGB(225, 0, 74, 173),
              width: 2.0,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          _submitDetails();
          FocusScope.of(context).unfocus();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.fromARGB(225, 0, 74, 173),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
        child: Text(
          'Submit',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            TextButton(
              onPressed: () {
                // Navigate to DashboardPage on button press
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DashboardPage()),
                );
              },
              child: Row(
                children: [
                  _appBarImage(),
                  const SizedBox(width: 10),
                  _title(),
                ],
              ),
            )
          ],
        ),
        toolbarHeight: 72,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField('What to inspect:', whatToInspectController),
            _buildTextField('Host Details:', hostDetailsController),
            _buildTextField('Site Name:', siteNameController),
            _buildTextField('Site Location:', _controllerSiteLocation),
            _buildTextField('Job Date:', _controllerJobDate),
            _buildTextField('Time:', _controllerJobTime),
            Center(
              child: Text(
                'Business Represented',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            _buildTextField('Company Name', companyNameController),
            _buildTextField('Reg No', regNoController),
            _buildTextField('Contact Person', contactPersonController),
            _buildTextField('Contact Number', contactNumberController),
            _buildTextField('Email Address', emailAddressController),
            _buildTextField('Physical Address', physicalAddressController),
            _buildTextField('Notes', notesController),
            const Padding(
              padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Center(
                child: Text(
                  'Upload Documents',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            _buildDocumentField('Document1'),
            _buildDocumentField('Document2'),
            _buildDocumentField('Document3'),
            _buildDocumentField('Document4'),
            _buildDocumentField('Document5'),
            SizedBox(height: 16.0),
            _buildSubmitButton(),
          ],
        ),
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
        return const Text('Dots');
      },
    );
  }

  Widget _title() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Text(
        'Tender Site Meeting',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }
}
