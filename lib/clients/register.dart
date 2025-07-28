import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard.dart';
import 'login_register_page.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:flutter/services.dart';
import 'terms.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/theme.dart'; // Assuming this contains the appGradient

class MapPickerDialog extends StatefulWidget {
  const MapPickerDialog({Key? key}) : super(key: key);

  @override
  _MapPickerDialogState createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(0, 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _selectedLocation = _currentLocation;
          _isLoading = false;
        });
        _mapController.move(_currentLocation, 15.0);
      }
    } catch (e) {
      print('Error getting current location: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Select Location',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color.fromARGB(225, 0, 74, 173),
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 400,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 15.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedLocation = point;
                  });
                },
              ),
              children: [
                // Use the working TileLayer from original implementation
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.yourapp.name',
                  tileProvider: NetworkTileProvider(),
                  maxZoom: 19,
                  keepBuffer: 5,
                  // Additional configurations for dark theme compatibility
                  tileBuilder: (context, child, tile) {
                    return child;
                  },
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 80,
                        height: 80,
                        child: Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (_isLoading)
              Center(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color.fromARGB(225, 0, 74, 173),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Loading location...'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(225, 0, 74, 173),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Select',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          onPressed: _selectedLocation == null
              ? null
              : () => Navigator.of(context).pop(_selectedLocation),
        ),
      ],
    );
  }
}

class GeoapifyPlace {
  final String formatted;
  final double lat;
  final double lon;

  GeoapifyPlace({
    required this.formatted,
    required this.lat,
    required this.lon,
  });
}

class GeoapifyLocationSuggestions {
  static const String apiKey = 'b980b19871164cc8b2651ee6e57d29e7';

  static Future<List<GeoapifyPlace>> fetchLocationSuggestions(
    String query,
  ) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final String url =
          'https://api.geoapify.com/v1/geocode/autocomplete?' +
          'text=${Uri.encodeComponent(query)}' +
          '&format=json' +
          '&apiKey=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];

        return results
            .map(
              (result) => GeoapifyPlace(
                formatted: result['formatted'] as String,
                lat: (result['lat'] is int)
                    ? (result['lat'] as int).toDouble()
                    : result['lat'] as double,
                lon: (result['lon'] is int)
                    ? (result['lon'] as int).toDouble()
                    : result['lon'] as double,
              ),
            )
            .toList();
      } else {
        throw Exception('Failed to fetch suggestions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching location suggestions: $e');
      rethrow;
    }
  }

  static Future<GeoapifyPlace?> reverseGeocode(double lat, double lon) async {
    try {
      final String url =
          'https://api.geoapify.com/v1/geocode/reverse?' +
          'lat=$lat&lon=$lon' +
          '&format=json' +
          '&apiKey=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];

        if (results.isNotEmpty) {
          final result = results[0];
          return GeoapifyPlace(
            formatted: result['formatted'] as String,
            lat: (result['lat'] is int)
                ? (result['lat'] as int).toDouble()
                : result['lat'] as double,
            lon: (result['lon'] is int)
                ? (result['lon'] as int).toDouble()
                : result['lon'] as double,
          );
        }
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
      rethrow;
    }
    return null;
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  String? errorMessage = '';
  bool isForMyself = true;
  bool idNumberSelected = true;
  bool passportNumberSelected = false;
  bool showPassword = false;
  bool isVerifyingEmail = false;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _addressFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<GeoapifyPlace> _addressSuggestions = [];
  bool isLoading = false;
  Timer? _timer;

  final TextEditingController _controllerFirstName = TextEditingController();
  final TextEditingController _controllerSurname = TextEditingController();
  final TextEditingController _controllerIDPassport = TextEditingController();
  final TextEditingController _controllerAddress = TextEditingController();
  final TextEditingController _controllerPhoneNumber = TextEditingController();
  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();
  final TextEditingController _controllerCompanyName = TextEditingController();
  final TextEditingController _controllerCompanyRegistration =
      TextEditingController();
  final TextEditingController _controllerVatRegistration =
      TextEditingController();

  FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? emailVerificationTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), _hideOverlay);
      }
    });
    _checkLocationPermissions();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  Future<void> _checkLocationPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedDialog(permanentlyDenied: true);
      return;
    }
  }

  void _showPermissionDeniedDialog({bool permanentlyDenied = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Location Permission Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color.fromARGB(225, 0, 74, 173),
            ),
          ),
          content: Text(
            permanentlyDenied
                ? 'Location permissions are permanently denied. Please enable them from settings.'
                : 'Location permission is needed to proceed. Please allow location access.',
            style: const TextStyle(color: Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (!permanentlyDenied)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(225, 0, 74, 173),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Request Again',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _checkLocationPermissions();
                },
              ),
          ],
        );
      },
    );
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _showLocationPicker() async {
    try {
      setState(() => isLoading = true);
      LatLng? selectedLocation = await showDialog<LatLng>(
        context: context,
        builder: (BuildContext context) {
          return const MapPickerDialog();
        },
      );

      if (selectedLocation != null) {
        try {
          final place = await GeoapifyLocationSuggestions.reverseGeocode(
            selectedLocation.latitude,
            selectedLocation.longitude,
          );

          if (place != null) {
            setState(() {
              _controllerAddress.text = place.formatted;
              isLoading = false;
            });
          } else {
            throw Exception('Failed to get address for selected location');
          }
        } catch (e) {
          print('Error in reverse geocoding: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get address for selected location'),
              backgroundColor: Colors.red.withOpacity(0.3),
            ),
          );
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error in location picker: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _getAddressSuggestions(String query) async {
    if (query.length < 2) {
      _hideOverlay();
      setState(() => _addressSuggestions = []);
      return;
    }

    setState(() => isLoading = true);

    try {
      final suggestions =
          await GeoapifyLocationSuggestions.fetchLocationSuggestions(query);
      setState(() {
        _addressSuggestions = suggestions;
        isLoading = false;
      });

      if (_addressSuggestions.isNotEmpty && _addressFocusNode.hasFocus) {
        _showAddressOverlay();
      }
    } catch (e) {
      print('Error getting suggestions: $e');
      setState(() => isLoading = false);
    }
  }

  void _showAddressOverlay() {
    _hideOverlay();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 48,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 70.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.1),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _addressSuggestions.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      _addressSuggestions[index].formatted,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    onTap: () {
                      setState(() {
                        _controllerAddress.text =
                            _addressSuggestions[index].formatted;
                      });
                      _hideOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _getCurrentLocationAndAddress() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        errorMessage = 'Location services are disabled.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          errorMessage = 'Location permissions are denied';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        errorMessage =
            'Location permissions are permanently denied, we cannot request permissions.';
      });
      return;
    }

    setState(() => isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks[0];

      setState(() {
        _controllerAddress.text =
            "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
        isLoading = false;
      });
    } catch (e) {
      print('Error getting current location and address: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> registerUser() async {
    if (!isLoading) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      try {
        UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: _controllerEmail.text.trim(),
              password: _controllerPassword.text.trim(),
            );

        await storeUserDataInFirestore(userCredential.user!.uid);
        await userCredential.user!.sendEmailVerification();
        await checkEmailVerified(userCredential.user!);
      } on FirebaseAuthException catch (e) {
        setState(() {
          errorMessage = e.message;
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> checkEmailVerified(User user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Verify Your Email',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color.fromARGB(225, 0, 74, 173),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A verification email has been sent to ${_controllerEmail.text}',
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 10),
              Text(
                'Please check your email and click the verification link.',
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 10),
              Text(
                'Waiting for email verification...',
                style: TextStyle(
                  color: const Color.fromARGB(225, 0, 74, 173),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );

    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        await user.reload();
        user = _auth.currentUser!;

        if (user.emailVerified) {
          _timer?.cancel();
          Navigator.of(context).pop();
          await _showEmailVerificationDialog(user);
        }
      } catch (e) {
        _timer?.cancel();
        setState(() {
          errorMessage = 'Error verifying email: ${e.toString()}';
        });
      }
    });
  }

  Future<void> _showEmailVerificationDialog(User user) async {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing until verification or cancel
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Verify Your Email',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color.fromARGB(225, 0, 74, 173),
            ),
          ),
          content: Text(
            'A verification email has been sent to ${_controllerEmail.text.trim()}. '
            'Please check your inbox (and spam/junk folder) and click the verification link to continue.',
            style: const TextStyle(color: Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              onPressed: () {
                emailVerificationTimer?.cancel();
                Navigator.of(context).pop();
                setState(() {
                  isVerifyingEmail = false;
                });
                // Optionally sign out the user if they cancel
                _auth.signOut();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(225, 0, 74, 173),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'I Verified',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                await user.reload();
                if (user.emailVerified) {
                  emailVerificationTimer?.cancel();
                  Navigator.of(context).pop();
                  setState(() {
                    isVerifyingEmail = true;
                  });
                  _navigateToRequestTypePage();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Email not yet verified. Please check your email.',
                      ),
                      backgroundColor: Colors.red.withOpacity(0.3),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void startEmailVerificationCheck(User user) {
    emailVerificationTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      await user.reload();
      if (user.emailVerified) {
        timer.cancel();
        setState(() {
          isVerifyingEmail = false;
        });
        // Close the dialog if still open
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _navigateToRequestTypePage();
      }
    });
  }

  Future<void> storeUserDataInFirestore(String uid) async {
    final docRef = FirebaseFirestore.instance.collection('register').doc(uid);

    await docRef.set({
      'firstName': _controllerFirstName.text.trim(),
      'surname': _controllerSurname.text.trim(),
      'idPassport': _controllerIDPassport.text.trim(),
      'address': _controllerAddress.text.trim(),
      'phoneNumber': _controllerPhoneNumber.text.trim(),
      'email': _controllerEmail.text.trim(),
    });

    if (!isForMyself) {
      await docRef.update({
        'companyName': _controllerCompanyName.text.trim(),
        'companyRegistration': _controllerCompanyRegistration.text.trim(),
        'vatRegistration': _controllerVatRegistration.text.trim(),
      });
    }
  }

  void _navigateToRequestTypePage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => DashboardPage()),
    );
  }

  Future<void> sendFirebaseSMS() async {
    await _auth.verifyPhoneNumber(
      phoneNumber: _controllerPhoneNumber.text,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        print('SMS verification completed');
      },
      verificationFailed: (FirebaseAuthException e) {
        print('SMS verification failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        print('SMS code sent');
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        print('SMS code retrieval timed out');
      },
      timeout: const Duration(seconds: 5),
    );
  }

  Widget _title() {
    return const Text(
      'DOTS',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontFamily: 'Quicksand',
        fontSize: 32,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _appBarImage() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Image.network(
          'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
          fit: BoxFit.contain,
          errorBuilder:
              (BuildContext context, Object exception, StackTrace? stackTrace) {
                return const Text(
                  'Image not found',
                  style: TextStyle(color: Colors.white),
                );
              },
        ),
      ),
    );
  }

  Widget _welcomeText() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Image.asset(
                        'assets/icons/icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 48),
          Text(
            'Hi! Welcome',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Quicksand',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please register below',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w300,
              fontFamily: 'Quicksand',
            ),
          ),
        ],
      ),
    );
  }

  Widget _userTypeToggleButtons() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  isForMyself = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color.fromARGB(225, 0, 74, 173),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Personal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isForMyself
                      ? const Color.fromARGB(225, 0, 74, 173)
                      : Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  isForMyself = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color.fromARGB(225, 0, 74, 173),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                'For A Business',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: !isForMyself
                      ? const Color.fromARGB(225, 0, 74, 173)
                      : Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _idPassportToggleButtons() {
    if (isForMyself) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
              value: idNumberSelected,
              onChanged: (bool? value) {
                setState(() {
                  idNumberSelected = value!;
                  passportNumberSelected = !value;
                });
              },
              activeColor: const Color.fromARGB(225, 0, 74, 173),
              checkColor: Colors.white,
            ),
            Text(
              'ID No.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 20),
            Checkbox(
              value: passportNumberSelected,
              onChanged: (bool? value) {
                setState(() {
                  passportNumberSelected = value!;
                  idNumberSelected = !value;
                });
              },
              activeColor: const Color.fromARGB(225, 0, 74, 173),
              checkColor: Colors.white,
            ),
            Text(
              'Passport No.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _entryField(
    String title,
    TextEditingController controller, {
    bool isPassword = false,
    bool isPhoneNumber = false,
    bool isNumeric = false,
    int? maxLength,
  }) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: isPhoneNumber
            ? InternationalPhoneNumberInput(
                onInputChanged: (PhoneNumber number) {
                  controller.text = number.phoneNumber!;
                },
                selectorConfig: const SelectorConfig(
                  selectorType: PhoneInputSelectorType.DIALOG,
                ),
                initialValue: PhoneNumber(isoCode: 'ZA'),
                textStyle: const TextStyle(color: Colors.white, fontSize: 16),
                inputDecoration: InputDecoration(
                  labelText: title,
                  labelStyle: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.white,
                      width: 2.0,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                ),
              )
            : TextField(
                controller: controller,
                obscureText: isPassword && !showPassword,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                inputFormatters: isNumeric
                    ? [
                        LengthLimitingTextInputFormatter(maxLength),
                        FilteringTextInputFormatter.digitsOnly,
                      ]
                    : null,
                decoration: InputDecoration(
                  labelText: title,
                  labelStyle: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.white,
                      width: 2.0,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  suffixIcon: isPassword
                      ? Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                showPassword = !showPassword;
                              });
                            },
                          ),
                        )
                      : null,
                ),
              ),
      ),
    );
  }

  Widget _addressField() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            controller: _controllerAddress,
            focusNode: _addressFocusNode,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Address',
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white, width: 2.0),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 20,
              ),
              suffixIcon: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.map, color: Colors.white),
                  onPressed: isLoading ? null : _showLocationPicker,
                ),
              ),
            ),
            onChanged: _getAddressSuggestions,
          ),
        ),
      ),
    );
  }

  Widget _forMyBusinessFields() {
    if (isForMyself) {
      return const SizedBox.shrink();
    } else {
      return SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const SizedBox(height: 16),
              _entryField('Company Name', _controllerCompanyName),
              const SizedBox(height: 16),
              _entryField('Company Reg Number', _controllerCompanyRegistration),
              const SizedBox(height: 16),
              _entryField('VAT Registration', _controllerVatRegistration),
            ],
          ),
        ),
      );
    }
  }

  Widget _submitButton() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isVerifyingEmail || isLoading ? null : registerUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color.fromARGB(225, 0, 74, 173),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(
              isVerifyingEmail ? 'Verifying Email...' : 'Register',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorMessage() {
    return errorMessage == null || errorMessage!.isEmpty
        ? const SizedBox.shrink()
        : SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red[300], fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _loginAccountLabel() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              child: const Text(
                'Log In',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _controllerFirstName.dispose();
    _controllerSurname.dispose();
    _controllerIDPassport.dispose();
    _controllerAddress.dispose();
    _controllerPhoneNumber.dispose();
    _controllerEmail.dispose();
    _controllerPassword.dispose();
    _controllerCompanyName.dispose();
    _controllerCompanyRegistration.dispose();
    _controllerVatRegistration.dispose();
    emailVerificationTimer?.cancel();
    _addressFocusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  if (isLargeScreen)
                    Expanded(
                      flex: 1,
                      child: Container(
                        color: const Color.fromARGB(225, 0, 74, 173),
                        child: Center(
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _appBarImage(),
                                  const SizedBox(height: 32),
                                  _title(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: isLargeScreen ? 2 : 1,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 100 : 24,
                          vertical: 40,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: _welcomeText(),
                            ),
                            const SizedBox(height: 48),
                            SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Registration Information',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _userTypeToggleButtons(),
                                      const SizedBox(height: 16),
                                      _idPassportToggleButtons(),
                                      const SizedBox(height: 16),
                                      _entryField(
                                        'First Name',
                                        _controllerFirstName,
                                      ),
                                      const SizedBox(height: 16),
                                      _entryField(
                                        'Surname',
                                        _controllerSurname,
                                      ),
                                      const SizedBox(height: 16),
                                      _entryField(
                                        'ID/Passport Number',
                                        _controllerIDPassport,
                                        isNumeric: false,
                                        maxLength: 13,
                                      ),
                                      const SizedBox(height: 16),
                                      _addressField(),
                                      const SizedBox(height: 16),
                                      _entryField(
                                        'Phone Number',
                                        _controllerPhoneNumber,
                                        isPhoneNumber: true,
                                      ),
                                      const SizedBox(height: 16),
                                      _entryField('Email', _controllerEmail),
                                      const SizedBox(height: 16),
                                      _entryField(
                                        'Password',
                                        _controllerPassword,
                                        isPassword: true,
                                      ),
                                      _forMyBusinessFields(),
                                      _errorMessage(),
                                      const SizedBox(height: 16),
                                      _submitButton(),
                                      _loginAccountLabel(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
