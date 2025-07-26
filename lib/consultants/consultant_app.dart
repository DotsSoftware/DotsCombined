import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'business_site.dart';
import 'client_business.dart'; //ClientBusinessPage
import 'site_meet.dart';

class ConsultantApp extends StatefulWidget {
  @override
  _ConsultantAppState createState() => _ConsultantAppState();
}

class Consultant {
  final String name;
  final String expertise;
  final double rating;

  Consultant({
    required this.name,
    required this.expertise,
    required this.rating,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'expertise': expertise,
      'rating': rating,
    };
  }

  factory Consultant.fromMap(Map<String, dynamic> map) {
    return Consultant(
      name: map['name'] as String,
      expertise: map['expertise'] as String,
      rating: map['rating'] as double,
    );
  }
}

class _ConsultantAppState extends State<ConsultantApp> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _expertise = '';
  double _rating = 0.0;
  bool _isAddingConsultant = false;
  List<Consultant> _consultants = [];

  @override
  void initState() {
    super.initState();
    _fetchConsultants();
  }

  Future<void> _fetchConsultants() async {
    final consultants =
        FirebaseFirestore.instance.collection('consultant_side');
    final snapshot = await consultants.get();

    setState(() {
      _consultants =
          snapshot.docs.map((doc) => Consultant.fromMap(doc.data())).toList();
    });
  }

  Future<void> _addConsultantToFirestore() async {
    final consultant = Consultant(
      name: _name,
      expertise: _expertise,
      rating: _rating,
    );

    final consultants =
        FirebaseFirestore.instance.collection('consultant_side');
    await consultants.add(consultant.toMap());

    setState(() {
      _name = '';
      _expertise = '';
      _rating = 0.0;
      _isAddingConsultant = false;
      _fetchConsultants();
    });
  }

  Widget _buildConsultantList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _consultants.length,
      itemBuilder: (context, index) {
        final consultant = _consultants[index];
        return ListTile(
          title: Text(consultant.name),
          subtitle:
              Text('${consultant.expertise} - Rating: ${consultant.rating}'),
        );
      },
    );
  }

  Widget _buildAddConsultantForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Name',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
            onSaved: (newValue) => _name = newValue!,
          ),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Expertise',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter expertise';
              }
              return null;
            },
            onSaved: (newValue) => _expertise = newValue!,
          ),
          Slider(
            value: _rating,
            min: 0.0,
            max: 5.0,
            divisions: 10,
            label: 'Rating: $_rating',
            onChanged: (newRating) {
              setState(() => _rating = newRating);
            },
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                await _addConsultantToFirestore();
              }
            },
            child: const Text('Add Consultant'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndNext({required String selectedType}) {
    // Implement your search logic here using selectedType

    return ElevatedButton(
      onPressed: () async {
        // ... search logic (optional)

        // Navigate to the NextTPage for consultant selection
        final userSelectedType = await FirebaseFirestore.instance
            .collection('consultant_side')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get()
            .then((doc) => doc.data()?['selected_type'] as String);

        Widget targetPage = SizedBox(); // Initialize with a default widget
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
              targetPage =
                  const Text('Invalid selection. Please contact support.');
          }
        } else {
          targetPage =
              const Text('User type not found. Please try again later.');
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetPage),
        );
      },
      child: const Text('Search & Next'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultant App'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Add Consultant form
              Visibility(
                visible: !_isAddingConsultant,
                child: ElevatedButton(
                  onPressed: () => setState(() => _isAddingConsultant = true),
                  child: const Text('Add Consultant'),
                ),
              ),
              Visibility(
                visible: _isAddingConsultant,
                child: Column(
                  children: [
                    _buildAddConsultantForm(),
                    ElevatedButton(
                      onPressed: () =>
                          setState(() => _isAddingConsultant = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              // Consultant List
              _buildConsultantList(),
              const SizedBox(height: 16.0),
              // Search & Next button
              _buildSearchAndNext(
                  selectedType: ''), // Pass the selected type here
            ],
          ),
        ),
      ),
    );
  }
}
