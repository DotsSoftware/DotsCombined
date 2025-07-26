import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'business_site.dart';
import 'client_business.dart';
import 'site_meet.dart';

class RedirectPage extends StatefulWidget {
  @override
  _RedirectPageState createState() => _RedirectPageState();
}

class _RedirectPageState extends State<RedirectPage> {
  bool _isCheckingNavigation = false;

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
    return CachedNetworkImage(
      imageUrl:
          'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
      height: 55,
      width: 55,
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) => const Text('Image not found'),
    );
  }

  Future<void> _checkAndNavigate(DocumentSnapshot document) async {
    if (!document.exists) {
      print('Error: No matching documents found');
      return;
    }

    try {
      final String selectedType = document.get('selected_type');

      if (selectedType == 'Business Site Inspection') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => BusinessSitePage()),
        );
      } else if (selectedType == 'Client Business Meeting') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ClientBusinessPage()),
        );
      } else if (selectedType == 'Tender Site Meeting') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => SiteMeetPage()),
        );
      } else {
        print('Error: selected_type is not recognized');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      // Handle the case where the user is not logged in
      // You might navigate to a login page here
      return;
    }

    FirebaseFirestore.instance
        .collection('selection')
        .doc(
          FirebaseAuth.instance.currentUser?.uid,
        ) // Access current user's document
        .collection('requests') // Access appointments subcollection
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (!_isCheckingNavigation) {
            _isCheckingNavigation = true;
            if (snapshot.docs.isNotEmpty) {
              _checkAndNavigate(snapshot.docs.first);
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [_appBarImage(), const SizedBox(width: 10), _title()],
        ),
        toolbarHeight: 70,
      ),
      body: const Center(
        child:
            CircularProgressIndicator(), // Show a loading indicator while checking navigation
      ),
    );
  }
}
