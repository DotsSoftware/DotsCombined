import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'business_site.dart'; // Import the new page
import 'package:firebase_storage/firebase_storage.dart';

class ClientBusinessPage extends StatefulWidget {
  @override
  _ClientBusinessPageState createState() => _ClientBusinessPageState();
}

class _ClientBusinessPageState extends State<ClientBusinessPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Define TextEditingController for each input field
  final TextEditingController whatToInspectController = TextEditingController();
  final TextEditingController hostDetailsController = TextEditingController();
  final TextEditingController siteNameController = TextEditingController();
  final TextEditingController siteAddressController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController businessTypeController = TextEditingController();
  final TextEditingController regNoController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController emailAddressController = TextEditingController();
  final TextEditingController physicalAddressController =
      TextEditingController();
  final TextEditingController notesController = TextEditingController();

  // Map to store file names corresponding to each file upload field
  Map<String, String?> documentFields = {
    'Document1': null,
    'Document2': null,
    'Document3': null,
    'Document4': null,
    'Document5': null,
  };

  CollectionReference siteMeetings =
      FirebaseFirestore.instance.collection('BusinessSiteInspection');

  Future<void> _pickDocument(String fieldName) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        documentFields[fieldName] = result.files.first.name;
      });

      // Upload the selected file to Firebase Storage
      // You should replace 'userEmail' with the actual user email
      String storagePath =
          'gs://fir-builds-eac7a.appspot.com/DOTSCLIENTS/${user!.email}/${result.files.first.name}';
      Reference storageReference =
          FirebaseStorage.instance.ref().child(storagePath);

      UploadTask uploadTask =
          storageReference.putData(result.files.first.bytes!);

      await uploadTask.whenComplete(() {
        print('File uploaded successfully');
      });
    } else {
      // User canceled the file picker
    }
  }

  void _submitDetails() {
    // Implement the logic to submit details to the database
    siteMeetings.add({
      'WhatToInspect': whatToInspectController.text,
      'HostDetails': hostDetailsController.text,
      'SiteName': siteNameController.text,
      'SiteAddress': siteAddressController.text,
      'Date': dateController.text,
      'Time': timeController.text,
      'CompanyName': companyNameController.text,
      'BusinessType': businessTypeController.text,
      'RegNo': regNoController.text,
      'ContactPerson': contactPersonController.text,
      'ContactNumber': contactNumberController.text,
      'EmailAddress': emailAddressController.text,
      'PhysicalAddress': physicalAddressController.text,
      'Notes': notesController.text,
      'Documents': documentFields,
    });

    // Navigate to the next page after submitting details
    _navigateToPayPage();
  }

  void _navigateToPayPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PayPage()),
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

  Widget _buildDocumentField(String fieldName) {
    return GestureDetector(
      onTap: () {
        _pickDocument(fieldName);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.0),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Color.fromARGB(225, 0, 74, 173),
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          documentFields[fieldName] ?? 'Select Document',
          style: TextStyle(
            color: Color.fromARGB(225, 0, 74, 173),
          ),
        ),
      ),
    );
  }

  Widget _buildHeading(String text) {
    return Container(
      margin: EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(225, 0, 74, 173),
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
          FocusScope.of(context).unfocus(); // Close the keyboard
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.fromARGB(225, 0, 74, 173),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
        child: Text('Submit'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _appBarImage(),
            const SizedBox(width: 10),
            _title(),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _welcomeText(),
            _buildTextField('What To Inspect', whatToInspectController),
            _buildTextField('Host Details', hostDetailsController),
            _buildTextField('Site Name', siteNameController),
            _buildTextField('Site Address', siteAddressController),
            _buildTextField('Date', dateController),
            _buildTextField('Time', timeController),
            _buildHeading('Business Represented'),
            _buildHeading('Company Details'),
            _buildTextField('Business Type', businessTypeController),
            _buildTextField('Reg No', regNoController),
            _buildTextField('Contact Person', contactPersonController),
            _buildTextField('Contact Number', contactNumberController),
            _buildTextField('Email Address', emailAddressController),
            _buildTextField('Physical Address', physicalAddressController),
            _buildTextField('Notes', notesController),
            SizedBox(height: 16.0),
            _buildHeading('Attachments'),
            for (String fieldName in documentFields.keys)
              _buildDocumentField(fieldName),
            SizedBox(height: 16.0),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

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
      height: 40,
      width: 40,
      errorBuilder:
          (BuildContext context, Object exception, StackTrace? stackTrace) {
        return const Text('Image not found');
      },
    );
  }
}

Widget _welcomeText() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          'Client Business Meeting',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: 'Quicksand',
          ),
        ),
      ],
    ),
  );
}

class PayPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Page'),
      ),
      body: Center(
        child: Text('This is the payment page'),
      ),
    );
  }
}
