
import 'package:dots/clients/business_site.dart';
import 'package:dots/clients/client_business.dart';
import 'package:dots/clients/site_meet.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NextTPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Implement the UI for the CompetencyPage
    return Scaffold(
      appBar: AppBar(
        title: Text('Competency Page'),
      ),
      body: Center(
        child: Text('Competency Page Content'),
      ),
    );
  }
}

class SearchPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Implement the UI for the SearchPage
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Page'),
      ),
      body: Center(
        child: Text('Search Page Content'),
      ),
    );
  }
}

class NextPage extends StatefulWidget {
  final Map<String, dynamic> selectedConsultant;

  const NextPage({Key? key, required this.selectedConsultant})
      : super(key: key);

  @override
  _NextPageState createState() => _NextPageState();
}

class _NextPageState extends State<NextPage> {
  String selectedType = '';

  @override
  void initState() {
    super.initState();
    _fetchSelectedType();
  }

  Future<void> _fetchSelectedType() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance.collection('alerts').doc(userId).get();

    setState(() {
      selectedType = snapshot.data()?['selected_type'] ?? '';
    });
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
      height: 55,
      width: 55,
      errorBuilder:
          (BuildContext context, Object exception, StackTrace? stackTrace) {
        return const Text('Image not found');
      },
    );
  }

  Widget _welcomeText() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.check,
              color: Colors.white,
              size: 70, // Adjust the size of the tick icon
            ),
            Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue, // Circle border color
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              const Text(
                'Consultant Found',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: 'Quicksand',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loginOrRegisterButton() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () async {
              // 1. Fetch the user's selected type from Firestore
              final userSelectedType = await FirebaseFirestore.instance
                  .collection('alerts')
                  .doc(/* Get the current user's ID here */)
                  .get()
                  .then((doc) => doc.data()?['selected_type'] as String);

              // 2. Determine the appropriate page to navigate to
              Widget targetPage =
                  SizedBox(); // Initialize with a default widget
              if (userSelectedType != null) {
                switch (userSelectedType) {
                  case 'Business Site Inspection':
                    targetPage = BusinessSitePage();
                    break;
                  case 'Client Business Meeting':
                    targetPage = ClientBusinessPage();
                    break;
                  case 'Tender Site Meeting':
                    targetPage = SiteMeetPage();
                    break;
                  default:
                    // Handle cases where there's no selected type or it's invalid
                    // You might show an error message or redirect to a default page
                    break;
                }
              } else {
                // Handle the case where userSelectedType is null (e.g., no data found)
                // You might show an error message or prompt the user to select a type
              }

              // 3. Navigate conditionally
              if (targetPage != SizedBox()) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => targetPage),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              backgroundColor: Color.fromARGB(225, 0, 74, 173),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Text(
                'Next',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
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
        toolbarHeight: 72,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _welcomeText(),
            SizedBox(height: 20.0),
            Text('Consultant Name: ${widget.selectedConsultant['name']}'),
            Text('Address/Details: ${widget.selectedConsultant['address']}'),
            Text('Skills Level: ${widget.selectedConsultant['selected_type']}'),
            Text('Address/Details: ${widget.selectedConsultant['address']}'),
            Text(
                'Industry Type: ${widget.selectedConsultant['industry_type']}'),
            const SizedBox(height: 20),
            Text(
              'Selected Type: $selectedType',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _showOptionsDialog();
              },
              child: Text('Continue Application'),
            ),
            const SizedBox(height: 20),
            _loginOrRegisterButton(),
          ],
        ),
      ),
    );
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select an Option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  _navigateToPage(SiteMeetPage());
                },
                child: Text('Tender Site Meeting'),
              ),
              ElevatedButton(
                onPressed: () {
                  _navigateToPage(BusinessSitePage());
                },
                child: Text('Business Site Inspection'),
              ),
              ElevatedButton(
                onPressed: () {
                  _navigateToPage(ClientBusinessPage());
                },
                child: Text('Client Business Meeting'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }
}
