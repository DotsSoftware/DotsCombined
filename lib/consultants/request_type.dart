import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment.dart';
import 'competency.dart';
// Import your other files as needed

class RequestTypePage extends StatefulWidget {
  const RequestTypePage({Key? key}) : super(key: key);

  @override
  State<RequestTypePage> createState() => _RequestTypePageState();
}

class _RequestTypePageState extends State<RequestTypePage>
    with WidgetsBindingObserver {
  String? errorMessage = 'Error';
  String? jobDescription;
  String? selectedButtonType;
  String? industryType;
  final TextEditingController _controllerEmail = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> subCategories = []; // Declare subCategories here
  String? currentUserEmail; // Declare currentUserEmail as String?

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _updateRequestStatus('Closed', 'Cancelled');
    }
  }

  void _updateRequestStatus(String status1, String status2) async {
    if (currentUserEmail != null) {
      await _firestore.collection('requests').doc(currentUserEmail).update({
        'status': status1,
        'status_2': status2, // If needed, use multiple status fields
      });
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          const Text(
            'Request Type',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(225, 0, 74, 173),
              fontFamily: 'Quicksand',
            ),
          ),
          const Text(
            'Please select below',
            style: TextStyle(
              fontSize: 22,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }

  Widget _siteButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: () {
          _selectButton('Tender Site Meeting');
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
          ),
          backgroundColor: selectedButtonType == 'Tender Site Meeting'
              ? Color.fromARGB(225, 0, 74, 173)
              : Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Text(
            'Tender Site Meeting',
            style: TextStyle(
              color: selectedButtonType == 'Tender Site Meeting'
                  ? Colors.white
                  : Color.fromARGB(225, 0, 74, 173),
            ),
          ),
        ),
      ),
    );
  }

  Widget _businessButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: () {
          _selectButton('Business Site Inspection');
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
          ),
          backgroundColor: selectedButtonType == 'Business Site Inspection'
              ? Color.fromARGB(225, 0, 74, 173)
              : Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Text(
            'Business Site Inspection',
            style: TextStyle(
              color: selectedButtonType == 'Business Site Inspection'
                  ? Colors.white
                  : Color.fromARGB(225, 0, 74, 173),
            ),
          ),
        ),
      ),
    );
  }

  Widget _clientButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      child: ElevatedButton(
        onPressed: () {
          _selectButton('Client Business Meeting');
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
          ),
          backgroundColor: selectedButtonType == 'Client Business Meeting'
              ? Color.fromARGB(225, 0, 74, 173)
              : Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Text(
            'Client Business Meeting',
            style: TextStyle(
              color: selectedButtonType == 'Client Business Meeting'
                  ? Colors.white
                  : Color.fromARGB(225, 0, 74, 173),
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryField(String title, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
      child: TextField(
        controller: controller,
        onChanged: (text) {
          jobDescription = text;
        },
        maxLines: null, // Set maxLines to null for multiline input
        decoration: InputDecoration(
          hintText: title,
          hintStyle: TextStyle(color: Color.fromARGB(225, 0, 74, 173)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(
              color: Color.fromARGB(225, 0, 74, 173),
              width: 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(
              color: Color.fromARGB(225, 0, 74, 173),
              width: 1.0,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        ),
      ),
    );
  }

  Widget _industryDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              _showIndustryDropdown();
            },
            child: Row(
              children: [
                Icon(Icons.arrow_drop_down,
                    size: 37, color: Color.fromARGB(225, 0, 74, 173)),
                const SizedBox(width: 10),
                Text(
                  industryType ?? 'Select Industry Type',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(225, 0, 74, 173),
                  ),
                ),
              ],
            ),
          ),
          if (industryType != null)
            _buildSubCategory(industryType!, subCategories),
        ],
      ),
    );
  }

  void _showIndustryDropdown() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 500,
          child: ListView(
            children: [
              _buildSubCategory('Agriculture', [
                'Animal Production',
                'Crop Production',
              ]),
              _buildSubCategory('Construction/Engineering', [
                'Building Construction',
                'Civil Works',
                'Electrical Works',
                'Equipment Hire',
                'Interior Design',
                'Landscaping/Sports Fields',
                'Mechanical Engineering',
                'Other (Chemistry/Automation/Solar/Biotechnology)',
                'Structural Engineering',
              ]),
              _buildSubCategory('Energy', [
                'Backup Power System',
                'Petrolium',
                'Solar Generation',
              ]),
              _buildSubCategory('Environmental', [
                'Conservation',
                'Environmental Management',
              ]),
              _buildSubCategory('Facility Management', [
                'Building Maintenance',
                'Cleaning Services',
                'Electrical Services',
                'HVAC Maintenance',
                'Plumbing Services',
                'Space Planning',
              ]),
              _buildSubCategory('Financial Services', [
                'Accountant',
                'Auditing',
                'Insurance',
              ]),
              _buildSubCategory('Health', [
                'Healthcare Services',
                'Medical Equipment Inspection',
              ]),
              _buildSubCategory('Legal', [
                'Legal Consultancy',
              ]),
              _buildSubCategory('Mining', [
                'Mining Operations',
                'Mining Support Services',
              ]),
              _buildSubCategory('Real Estate', [
                'Building Inspector',
              ]),
              _buildSubCategory('Security', [
                'General Security',
                'Security Systems & Surveillance',
              ]),
              _buildSubCategory('Other', [
                'Business Consulting',
                'Car Mechanical',
                'Marketing',
                'Media and Entertainment',
              ]),
            ],
          ),
        );
      },
    ).then((value) {
      if (value != null) {
        setState(() {
          industryType = value;
        });
      }
    });
  }

  Widget _buildSubCategory(String mainCategory, List<String> subCategories) {
    return ExpansionTile(
      title: GestureDetector(
        onTap: () {
          // Handle main category selection if needed
        },
        child: Row(
          children: [
            const SizedBox(width: 10),
            Text(
              mainCategory,
              style: TextStyle(
                fontSize: 16,
                color: Color.fromARGB(225, 0, 74, 173),
              ),
            ),
          ],
        ),
      ),
      children: subCategories.map((subCategory) {
        return ListTile(
          title: GestureDetector(
            onTap: () {
              _storeSelectedValues(mainCategory, subCategory);
              Navigator.of(context).pop(); // Close the bottom sheet
            },
            child: Text(subCategory),
          ),
        );
      }).toList()
        ..add(
          ListTile(
            title: Row(
              children: [
                Text(
                  'Other',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(225, 0, 74, 173),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (text) {
                      // Update industryType with the entered text
                      setState(() {
                        industryType = text;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter Industry',
                      border:
                          InputBorder.none, // Remove border for a cleaner look
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  void _storeSelectedValues(String mainCategory, String subCategory) {
    if (subCategory == 'Other') {
      // Industry type is set in the TextField onChanged callback
      return;
    }
    print('Selected Main Category: $mainCategory, Sub Category: $subCategory');
    setState(() {
      industryType = subCategory;
    });
  }

  Widget _errorMessage() {
    return Text(errorMessage == '' ? '' : 'Error ? $errorMessage');
  }

  Widget _loginOrRegisterButton() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              if (_isValidSelection()) {
                _storeDataAndNavigate();
              } else {
                _showIncompleteSelectionPrompt();
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

  void _selectButton(String type) {
    setState(() {
      selectedButtonType = type;
    });
  }

  void _storeDataAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final userEmail = user.email;

      final userData = {
        'user_id': userId,
        'userEmail': userEmail, // Add email to userData
        'selected_type': selectedButtonType,
        'industry_type': industryType,
        'status': 'Active', // Initial status
      };

      DocumentReference docRef =
          await FirebaseFirestore.instance.collection('requests').add(userData);

      // Save the request ID to change the status later
      setState(() {
        currentUserEmail = userEmail;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AppointmentPage(
            requestType: selectedButtonType ?? '',
            industryType: industryType ?? '',
          ),
        ),
      );
    }
  }

  void _showIncompleteSelectionPrompt() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(
              color: Color.fromARGB(225, 0, 74, 173), // Blue border color
              width: 2.0,
            ),
          ),
          title: Center(
            child: Text(
              'Incomplete Selection',
              style: TextStyle(
                color: Color.fromARGB(225, 0, 74, 173), // Blue text color
              ),
            ),
          ),
          content: Center(
            child: Text(
              'Complete selection to continue.',
              style: TextStyle(
                color: Color.fromARGB(225, 0, 74, 173), // Blue text color
              ),
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
              horizontal: 20, vertical: 4), // Adjust padding as needed
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: Color.fromARGB(225, 0, 74, 173), // Blue text color
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isValidSelection() {
    return selectedButtonType != null &&
        industryType != null &&
        industryType!.isNotEmpty;
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
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _welcomeText(),
              _siteButton(),
              _businessButton(),
              _clientButton(),
              _industryDropdown(),
              _loginOrRegisterButton(),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: RequestTypePage(),
  ));
}
