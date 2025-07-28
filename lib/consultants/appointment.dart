import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'industry_selection.dart';
import '../utils/theme.dart';

class AppointmentPage extends StatefulWidget {
  final String requestType;
  final String industryType;

  const AppointmentPage({
    Key? key,
    required this.requestType,
    required this.industryType,
  }) : super(key: key);

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage>
    with TickerProviderStateMixin {
  final TextEditingController _controllerJobDate = TextEditingController();
  final TextEditingController _controllerJobTime = TextEditingController();
  final TextEditingController _controllerSiteLocation = TextEditingController();
  final TextEditingController _controllerVehicleType = TextEditingController();

  bool _privateTransportSelected = true;
  bool _publicTransportSelected = false;
  double _travelDistance = 50;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, double>? _coordinates;

  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideUpAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _getCurrentLocationAndAddress();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideUpAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controllerJobDate.dispose();
    _controllerJobTime.dispose();
    _controllerSiteLocation.dispose();
    _controllerVehicleType.dispose();
    super.dispose();
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
                ),
                const SizedBox(width: 16),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.3),
              width: 2.0,
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
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildTransportOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : Colors.white.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceSlider() {
    List<double> points = [50, 300, 500, 1000, 1500];

    return Column(
      children: [
        Slider(
          value: _travelDistance,
          min: 0,
          max: 1500,
          divisions: 30,
          label: '${_travelDistance.round()} km',
          onChanged: (double value) {
            double closestPoint = points.reduce(
              (a, b) => (a - value).abs() < (b - value).abs() ? a : b,
            );
            setState(() {
              _travelDistance = closestPoint;
            });
          },
          activeColor: Colors.white,
          inactiveColor: Colors.white.withOpacity(0.3),
        ),
        Text(
          'Maximum distance willing to travel: ${_travelDistance.round()} km',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _getCurrentLocationAndAddress() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _controllerSiteLocation.text =
              "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
          _coordinates = {'lat': position.latitude, 'lng': position.longitude};
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showLocationPicker() async {
    LatLng? selectedLocation = await showDialog(
      context: context,
      builder: (BuildContext context) => MapPickerDialog(),
    );

    if (selectedLocation != null) {
      setState(() => _isLoading = true);
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          selectedLocation.latitude,
          selectedLocation.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _controllerSiteLocation.text =
                "${place.street}, ${place.locality}, ${place.country}";
            _coordinates = {
              'lat': selectedLocation.latitude,
              'lng': selectedLocation.longitude,
            };
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to get address for selected location';
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _storeAppointmentData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      if (_controllerSiteLocation.text.isEmpty || _coordinates == null) {
        throw Exception('Please select a valid location');
      }

      final appointmentData = {
        'siteLocation': _controllerSiteLocation.text,
        'vehicleType': _controllerVehicleType.text,
        'travelDistance': _travelDistance,
        'coordinates': _coordinates,
        'privateTransport': _privateTransportSelected,
        'publicTransport': _publicTransportSelected,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('consultant_side')
          .doc(user.uid)
          .set({'appointment': appointmentData}, SetOptions(merge: true));

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => IndustrySelectionPage()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $_errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildNextButton() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _storeAppointmentData,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFF0F0F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF1E3A8A),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Next',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading location...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      FadeTransition(
                        opacity: _fadeInAnimation,
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF1E3A8A),
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Location Information',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This info needs to be accurate',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Location Section
                      SlideTransition(
                        position: _slideUpAnimation,
                        child: FadeTransition(
                          opacity: _fadeInAnimation,
                          child: _buildSectionCard(
                            title: 'Location',
                            icon: Icons.location_on_outlined,
                            child: Column(
                              children: [
                                _buildModernTextField(
                                  label: 'Site Location',
                                  controller: _controllerSiteLocation,
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.map,
                                      color: Colors.white,
                                    ),
                                    onPressed: _showLocationPicker,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Transport Mode Section
                      SlideTransition(
                        position: _slideUpAnimation,
                        child: FadeTransition(
                          opacity: _fadeInAnimation,
                          child: _buildSectionCard(
                            title: 'Transport Mode',
                            icon: Icons.directions_outlined,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _buildTransportOption(
                                      title: 'Public',
                                      isSelected: _publicTransportSelected,
                                      onTap: () {
                                        setState(() {
                                          _publicTransportSelected =
                                              !_publicTransportSelected;
                                        });
                                      },
                                      icon: Icons.directions_bus,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildTransportOption(
                                      title: 'Private',
                                      isSelected: _privateTransportSelected,
                                      onTap: () {
                                        setState(() {
                                          _privateTransportSelected =
                                              !_privateTransportSelected;
                                        });
                                      },
                                      icon: Icons.directions_car,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 13),
                                _buildModernTextField(
                                  label: 'Vehicle Details (Private)',
                                  controller: _controllerVehicleType,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Distance Section
                      SlideTransition(
                        position: _slideUpAnimation,
                        child: FadeTransition(
                          opacity: _fadeInAnimation,
                          child: _buildSectionCard(
                            title: 'Travel Distance',
                            icon: Icons.straighten_outlined,
                            child: _buildDistanceSlider(),
                          ),
                        ),
                      ),

                      // Error Message
                      if (_errorMessage != null)
                        SlideTransition(
                          position: _slideUpAnimation,
                          child: FadeTransition(
                            opacity: _fadeInAnimation,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Next Button
                      SlideTransition(
                        position: _slideUpAnimation,
                        child: FadeTransition(
                          opacity: _fadeInAnimation,
                          child: _buildNextButton(),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class MapPickerDialog extends StatefulWidget {
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFF1E3A8A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Select Location',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Map
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              height: 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation,
                  initialZoom: 15.0,
                  minZoom: 4.0,
                  maxZoom: 18.0,
                  onTap: (tapPosition, point) {
                    setState(() => _selectedLocation = point);
                  },
                ),
                children: [
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
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Buttons
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            Navigator.of(context).pop(_selectedLocation),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Select',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
