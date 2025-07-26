import 'dart:async';
import 'industry_selection.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiver/async.dart';

class SearchPage extends StatefulWidget {
  final String requestType;
  final String industryType;

  const SearchPage({
    Key? key,
    required this.requestType,
    required this.industryType,
  }) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String? errorMessage = '';
  bool isLogin = true;
  bool isLoading = true;
  bool isConsultantAvailable = false;
  bool isButtonEnabled = false;
  bool showNoConsultantsText = false;
  int countdownSeconds = 30; // Initial countdown value
  late CountdownTimer countdownTimer;
  late List<Map<String, dynamic>> availableConsultants;
  Map<String, dynamic>? selectedConsultant;

  final TextEditingController _controllerEmail = TextEditingController();

  Future<void> resetPassword() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _controllerEmail.text,
      );
      // Show success message or navigate to another page if needed
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Future<void> searchForConsultants() async {
    try {
      await Future.delayed(const Duration(seconds: 30));

      final clientSnapshot =
          await FirebaseFirestore.instance.collection('Clients').get();

      if (clientSnapshot.docs.isNotEmpty) {
        availableConsultants = clientSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        isConsultantAvailable = true;
      } else {
        isConsultantAvailable = false;
        showNoConsultantsText = true;
        countdownSeconds = 20; // Stop the countdown immediately
      }

      setState(() {
        isLoading = false;
        isButtonEnabled = isConsultantAvailable;
      });
    } catch (e) {
      print('Error retrieving clients: $e');
    }
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

  Widget _firebaseImage() {
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          isLoading
              ? 'Searching For An\n Available Consultant'
              : showNoConsultantsText
                  ? 'They’re Currently No Available Consultants.'
                  : '',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(225, 0, 74, 173),
            fontFamily: 'Quicksand',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _loadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100, // Increased width
            height: 100, // Increased height
            child: CircularProgressIndicator(
              strokeWidth: 20, // Increased stroke width
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.fromARGB(225, 0, 74, 173),
              ),
              semanticsLabel: 'Searching...',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Searching...',
            style: TextStyle(
              fontSize: 16,
              color: Color.fromARGB(225, 0, 74, 173),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Please wait, while we look for an available consultant.',
            style: TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 173, 0, 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availableConsultantsTable() {
    if (availableConsultants.isEmpty) {
      return SizedBox.shrink();
    }

    final consultant = availableConsultants.first;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consultant Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 0, 0, 139),
            ),
          ),
          SizedBox(height: 20),
          Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sat 18 May 2024, 07:45',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '23 Trouw St, Johannesburg, 0067',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[200],
                        child: Icon(Icons.person, size: 40, color: Colors.blue),
                      ),
                      SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            consultant['name'] ?? 'Matome M',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Level 2',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            'Industry Type: Civil Works',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Handle button press
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
          ),
        ],
      ),
    );
  }

  Widget _noConsultantsText() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20), // Adjust horizontal padding as needed
      child: const Icon(
        Icons.sentiment_very_dissatisfied_outlined,
        size: 40,
        color: Color.fromARGB(225, 0, 74, 173),
      ),
    );
  }

  Widget _searchText() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          showNoConsultantsText
              ? 'Couldn’t find any available consultant, please try another search criteria'
              : '',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontFamily: 'Quicksand',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _nextButton() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      child: isLoading
          ? SizedBox.shrink() // Hide the button if still loading
          : ElevatedButton(
              onPressed: () {
                if (showNoConsultantsText) {
                  // Navigate to CompetencyPage
                } else if (isButtonEnabled && selectedConsultant != null) {
                  // Navigate to Next Page
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
                  showNoConsultantsText
                      ? 'Try another search criteria'
                      : 'Next',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
    );
  }

  Widget _backButton() {
    return Column(
      children: [
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => IndustrySelectionPage()),
            );
          },
          child: Row(
            children: [
              const SizedBox(width: 15),
              Text(
                'Back',
                style: TextStyle(
                  color: Color.fromARGB(225, 0, 74, 173),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // Start loading and searching for consultants
    searchForConsultants();
  }

  void startCountdown() {
    countdownTimer = CountdownTimer(
      Duration(seconds: countdownSeconds),
      Duration(seconds: 20),
    );

    countdownTimer.listen((event) {
      setState(() {
        countdownSeconds = event.remaining.inSeconds;
      });

      if (event.remaining.inSeconds == 0) {
        countdownTimer.cancel();
        setState(() {
          isLoading = false;
          isButtonEnabled = isConsultantAvailable;
          if (!isConsultantAvailable) {
            showNoConsultantsText = true;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const SizedBox(width: 10),
            _firebaseImage(),
            const SizedBox(width: 10),
            _title(),
          ],
        ),
        toolbarHeight: 72,
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _welcomeText(),
              const SizedBox(height: 50),
              isLoading ? _loadingIndicator() : _buildConsultantsWidget(),
              const SizedBox(height: 50),
              _searchText(),
              const SizedBox(height: 50),
              _nextButton(),
              const SizedBox(height: 50),
              _backButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsultantsWidget() {
    if (isConsultantAvailable) {
      return _availableConsultantsTable();
    } else {
      return _noConsultantsText(); // Removed the duplicated function call
    }
  }
}

void main() {
  runApp(MaterialApp(
    home: SearchPage(
      requestType: '', // Pass your request type here
      industryType: '', // Pass your industry type here
    ),
  ));
}
