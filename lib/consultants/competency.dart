import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'search.dart';
import 'appointment.dart';

class CompetencyPage extends StatefulWidget {
  final String requestType;
  final String industryType;

  const CompetencyPage({
    Key? key,
    required this.requestType,
    required this.industryType,
  }) : super(key: key);

  @override
  _CompetencyPageState createState() => _CompetencyPageState();
}

class _CompetencyPageState extends State<CompetencyPage> {
  String? errorMessage = 'Error';
  String? selectedCompetencyType;
  String? selectedDistanceType;
  String? jobDescription = 'Select Job Description';
  double totalPrice = 0.0;
  double vatAmount = 0.0;
  bool isForMyself = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, String> buttonDescriptions = {
    'Level 1 - Basic Knowledge':
        'Basic knowledge in presenting and gathering of information. With little or no industry-specific experience.',
    'Level 2 - Skilled In Industry':
        'Skilled in the selected industry, to be able to identify, gather and present information. Including those with work experience. Can offer advice and solutions to general issues.',
    'Level 3 - High Level Of Expertise':
        'High level of expertise in the industry, to the level of experienced professionals. Can offer solutions and advice on industry-specific issues, including options and costings, if necessary.',
  };

  double calculateTotalPrice() {
    double competencyPrice = selectedCompetencyType != null
        ? double.parse(_getButtonValue(selectedCompetencyType!) ?? '0.0')
        : 0.0;

    double distancePrice = selectedDistanceType != null
        ? double.parse(_getButtonValue(selectedDistanceType!) ?? '0.0')
        : 0.0;

    // Calculate total price excluding VAT
    double totalPriceExcludingVAT = competencyPrice + distancePrice;

    // Calculate VAT on the total price (excluding VAT)
    double vat = totalPriceExcludingVAT * 0.15;

    // Calculate total price including VAT
    double totalPrice = totalPriceExcludingVAT + vat;

    // Update the total price variable in the state
    setState(() {
      this.totalPrice = totalPrice;
      this.vatAmount = vat;
    });

    return totalPrice;
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
          const SizedBox(height: 10),
          const Text(
            'Level Of Competency',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(225, 0, 74, 173),
              fontFamily: 'Quicksand',
            ),
          ),
          const Text(
            'Please build your consultant up',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _travelText() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          const SizedBox(height: 15),
          const Text(
            'Travel Requirements',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Quicksand',
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillLevelButton(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              _selectCompetencyButton(title, value);
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
              ),
              backgroundColor: selectedCompetencyType == title
                  ? Color.fromARGB(225, 0, 74, 173)
                  : Colors.white,
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: selectedCompetencyType == title
                        ? Colors.white
                        : Color.fromARGB(225, 0, 74, 173),
                  ),
                ),
                const Spacer(),
                Text(
                  'R$value',
                  style: TextStyle(
                    color: selectedCompetencyType == title
                        ? Colors.white
                        : Color.fromARGB(225, 0, 74, 173),
                  ),
                ),
              ],
            ),
          ),
          if (selectedCompetencyType == title)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                buttonDescriptions[title]!,
                style: TextStyle(
                  color: Color.fromARGB(225, 0, 74, 173),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectCompetencyButton(String type, String value) {
    setState(() {
      if (selectedCompetencyType == type) {
        selectedCompetencyType = null;
      } else {
        selectedCompetencyType = type;
        // Calculate total price when competency type changes
        calculateTotalPrice();
      }
    });
  }

  Widget _userTypeToggleButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            setState(() {
              isForMyself = true;
              selectedDistanceType = null; // Reset selected distance type
              calculateTotalPrice();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isForMyself ? Color.fromARGB(225, 0, 74, 173) : Colors.white,
            side: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            minimumSize: Size(30, 30), // Adjust the width and height here
            padding: EdgeInsets.symmetric(vertical: 13, horizontal: 15),
          ),
          child: Text(
            'Public Transport',
            style: TextStyle(
              color:
                  isForMyself ? Colors.white : Color.fromARGB(225, 0, 74, 173),
            ),
          ),
        ),
        SizedBox(width: 15),
        ElevatedButton(
          onPressed: () {
            setState(() {
              isForMyself = false;
              selectedDistanceType = null; // Reset selected distance type
              calculateTotalPrice();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                !isForMyself ? Color.fromARGB(225, 0, 74, 173) : Colors.white,
            side: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            minimumSize: Size(30, 30), // Adjust the width and height here
            padding: EdgeInsets.symmetric(vertical: 13, horizontal: 15),
          ),
          child: Text(
            'Own Vehicle',
            style: TextStyle(
              color:
                  !isForMyself ? Colors.white : Color.fromARGB(225, 0, 74, 173),
            ),
          ),
        ),
      ],
    );
  }

  Widget _distanceButton(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: () {
          _selectDistanceButton(title, value);
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
          ),
          backgroundColor: selectedDistanceType == title
              ? Color.fromARGB(225, 0, 74, 173)
              : Colors.white,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: selectedDistanceType == title
                    ? Colors.white
                    : Color.fromARGB(225, 0, 74, 173),
              ),
            ),
            const Spacer(),
            Text(
              'R$value',
              style: TextStyle(
                color: selectedDistanceType == title
                    ? Colors.white
                    : Color.fromARGB(225, 0, 74, 173),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDistanceButton(String type, String value) {
    setState(() {
      if (selectedDistanceType == type) {
        selectedDistanceType = null;
      } else {
        selectedDistanceType = type;
        // Calculate total price when distance type changes
        calculateTotalPrice();
      }
    });
  }

  Widget _totalPriceDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            'Total Price',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Quicksand',
            ),
          ),
          Text(
            'R${totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              color: Color.fromARGB(225, 0, 74, 173),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'VAT: R${vatAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              color: Color.fromARGB(255, 0, 74, 173),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: _storeDataAndNavigate,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: Color.fromARGB(225, 0, 74, 173)),
          ),
          backgroundColor: Color.fromARGB(225, 0, 74, 173),
        ),
        child: const Text(
          'Accept',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String? _getButtonValue(String title) {
    Map<String, String> buttonValues = {
      'Level 1 - Basic Knowledge': '500.00',
      'Level 2 - Skilled In Industry': '937.50',
      'Level 3 - High Level Of Expertise': '2187.50',
      'Local - Within a 50km Radius ': '187.50',
      'Regional - Within a 300km Radius ': '375.00',
      'National - Within a 1500km Radius ': '6250.50',
      'Local - Within a 50km Radius': '437.50',
      'Regional - Within a 300km Radius': '1312.50',
      'Provincial - Within a 500km Radius': '1750.00',
      'Interprovincial - Within a 1000km Radius': '3106.25',
      'National - Within a 1500km Radius': '10937.50',
    };

    return buttonValues[title];
  }

  Widget _backButton() {
    return Column(
      children: [
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AppointmentPage(
                        requestType: widget.requestType,
                        industryType: widget.industryType,
                      )),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove back arrow
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _welcomeText(),
            _skillLevelButton('Level 1 - Basic Knowledge', '500.00'),
            _skillLevelButton('Level 2 - Skilled In Industry', '937.50'),
            _skillLevelButton('Level 3 - High Level Of Expertise', '2187.50'),
            _travelText(),
            _userTypeToggleButtons(),
            if (isForMyself)
              _distanceButton('Local - Within a 50km Radius', '187.50'),
            if (isForMyself)
              _distanceButton('Regional - Within a 300km Radius', '375.00'),
            if (isForMyself)
              _distanceButton('National - Within a 1500km Radius', '6250.50'),
            if (!isForMyself)
              _distanceButton('Local - Within a 50km Radius', '437.50'),
            if (!isForMyself)
              _distanceButton('Regional - Within a 300km Radius', '1312.50'),
            if (!isForMyself)
              _distanceButton('Provincial - Within a 500km Radius', '1750.00'),
            if (!isForMyself)
              _distanceButton(
                  'Interprovincial - Within a 1000km Radius', '3106.25'),
            if (!isForMyself)
              _distanceButton('National - Within a 1500km Radius', '10937.50'),
            _totalPriceDisplay(),
            _submitButton(),
            _backButton(),
          ],
        ),
      ),
    );
  }

  void _storeDataAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;

      final userData = {
        'user_id': userId,
        'selected_type': selectedCompetencyType,
        'selected_distance': selectedDistanceType,
        'job_description': jobDescription,
        'total_price': totalPrice.toString(),
      };

      await _firestore.collection('alerts').add(userData);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SearchPage(
            requestType:
                selectedCompetencyType!, // Assuming selectedCompetencyType is not null
            industryType:
                selectedDistanceType!, // Assuming selectedDistanceType is not null
          ),
        ),
      );
    }
  }
}
