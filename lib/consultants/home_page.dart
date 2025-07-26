import 'package:dots/consultants/consultant_login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth.dart';
import 'cart.dart';
import 'profile.dart';
import 'industry_selection.dart'; // Import the new page

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;
  bool detailsSubmitted = false; // Track whether details are submitted

  // Define TextEditingController for each input field
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController companyRegistrationNumberController =
      TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController emailAddressController = TextEditingController();
  final TextEditingController physicalAddressController =
      TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();

  CollectionReference requesterDetails = FirebaseFirestore.instance.collection(
    'RequesterDetails',
  );

  void _submitDetails() {
    // Implement the logic to submit details to the database
    requesterDetails.add({
      'FirstName': firstNameController.text,
      'Surname': surnameController.text,
      'CompanyName': companyNameController.text,
      'CompanyRegistrationNumber': companyRegistrationNumberController.text,
      'ContactPerson': contactPersonController.text,
      'ContactNumber': contactNumberController.text,
      'EmailAddress': emailAddressController.text,
      'PhysicalAddress': physicalAddressController.text,
      'PostalCode': postalCodeController.text,
    });

    setState(() {
      detailsSubmitted = true;
    });

    // Navigate to the next page after submitting details
    _navigateToRequestTypePage();
  }

  void _navigateToRequestTypePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => IndustrySelectionPage()),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
          ),
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
          backgroundColor: Colors.blue,
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
        title: Text('DOTS CLIENTS'),
        actions: [_buildHamburgerMenu(context)],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Requesters Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 20),
            _buildTextField('First Name(s)', firstNameController),
            _buildTextField('Surname', surnameController),
            _buildTextField('Company Name', companyNameController),
            _buildTextField(
              'Company Registration Number',
              companyRegistrationNumberController,
            ),
            _buildTextField('Contact Person', contactPersonController),
            _buildTextField('Contact Number', contactNumberController),
            _buildTextField('Email Address', emailAddressController),
            _buildTextField('Physical Address', physicalAddressController),
            _buildTextField('Postal Code', postalCodeController),
            SizedBox(height: 20),
            if (detailsSubmitted) // Show text only if details are submitted
              Text('Details submitted', style: TextStyle(color: Colors.green)),
            SizedBox(height: 10),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHamburgerMenu(BuildContext context) {
    return PopupMenuButton(
      itemBuilder:
          (BuildContext context) => [
            PopupMenuItem(
              child: Text('Locate Personnel'),
              value: 'Locate Personnel',
            ),
            PopupMenuItem(
              child: Text('Update Profile'),
              value: 'Update Profile',
            ),
            PopupMenuItem(child: Text('Sign Out'), value: 'signOut'),
          ],
      onSelected: (selectedOption) {
        switch (selectedOption) {
          case 'payments':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage()),
            );
            break;
          case 'rides':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage()),
            );
            break;
          case 'chat':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage()),
            );
            break;
          case 'signOut':
            _signOut();
            break;
        }
      },
    );
  }

  // Add a signOut method if not already defined
  void _signOut() async {
    // Implement the logic to sign out
    print('Signing out');
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => ConsultantLoginPage(),
      ),
    );
  }
}
