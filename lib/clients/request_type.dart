import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment.dart';
import 'dashboard.dart';
import '../utils/theme.dart';

class RequestTypePage extends StatefulWidget {
  const RequestTypePage({Key? key}) : super(key: key);

  @override
  State<RequestTypePage> createState() => _RequestTypePageState();
}

class _RequestTypePageState extends State<RequestTypePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  String? errorMessage = 'Error';
  String? jobDescription;
  String? selectedButtonType;
  String? industryType;
  final TextEditingController _controllerEmail = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> subCategories = [];
  String? currentUserEmail;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideUpAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
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
    WidgetsBinding.instance.removeObserver(this);
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

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required String value,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Radio<String>(
                  value: value,
                  groupValue: groupValue,
                  onChanged: onChanged,
                  activeColor: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndustryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: ListTile(
        title: Text(
          industryType ?? 'Select Industry Type',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        trailing: Icon(
          Icons.arrow_drop_down,
          color: Colors.white.withOpacity(0.8),
        ),
        onTap: _showIndustryDropdown,
      ),
    );
  }

  void _showIndustryDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: appGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Select Industry Type',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
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
                      'Petroleum',
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
                    _buildSubCategory('Legal', ['Legal Consultancy']),
                    _buildSubCategory('Mining', [
                      'Mining Operations',
                      'Mining Support Services',
                    ]),
                    _buildSubCategory('Real Estate', ['Building Inspector']),
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
              ),
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
      title: Text(mainCategory, style: const TextStyle(color: Colors.white)),
      children: subCategories.map((subCategory) {
        return ListTile(
          title: Text(subCategory, style: const TextStyle(color: Colors.white)),
          onTap: () {
            _storeSelectedValues(mainCategory, subCategory);
            Navigator.of(context).pop();
          },
        );
      }).toList(),
    );
  }

  Widget _buildNextButton() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isValidSelection() ? _storeDataAndNavigate : null,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF1E3A8A),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Continue',
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

  void _storeSelectedValues(String mainCategory, String subCategory) {
    setState(() {
      industryType = subCategory;
    });
  }

  bool _isValidSelection() {
    return selectedButtonType != null &&
        industryType != null &&
        industryType!.isNotEmpty;
  }

  Future<void> _storeDataAndNavigate() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final userEmail = user.email;

        final userData = {
          'userId': userId,
          'userEmail': userEmail,
          'selected_type': selectedButtonType,
          'industry_type': industryType,
          'status': 'Active',
          'timestamp': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('selection')
            .doc(userId)
            .collection('requests')
            .add(userData);

        if (userEmail != null) {
          final integratedDoc = await FirebaseFirestore.instance
              .collection('integrated')
              .doc(userEmail)
              .get();

          List<dynamic> existingRequests =
              integratedDoc.data()?['requests'] ?? [];

          bool dataExists = existingRequests.any(
            (request) =>
                request['selected_type'] == selectedButtonType &&
                request['industry_type'] == industryType,
          );

          if (!dataExists) {
            await FirebaseFirestore.instance
                .collection('integrated')
                .doc(userEmail)
                .set({
                  'requests': FieldValue.arrayUnion([
                    {
                      'userId': userId,
                      'userEmail': userEmail,
                      'selected_type': selectedButtonType,
                      'industry_type': industryType,
                      'status': 'Active',
                      'timestamp': DateTime.now().toIso8601String(),
                    },
                  ]),
                }, SetOptions(merge: true));
          }
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentPage(
              requestType: selectedButtonType ?? '',
              industryType: industryType ?? '',
            ),
          ),
        );

        setState(() {
          currentUserEmail = userEmail;
        });
      }
    } catch (e) {
      setState(() => errorMessage = 'Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
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
                        'Processing your request...',
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
                                Icons.description_outlined,
                                color: Color(0xFF1E3A8A),
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Request Type',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select the type of request you need',
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

                      // Request Type Section
                      SlideTransition(
                        position: _slideUpAnimation,
                        child: FadeTransition(
                          opacity: _fadeInAnimation,
                          child: _buildSectionCard(
                            title: 'Request Type',
                            icon: Icons.category_outlined,
                            child: Column(
                              children: [
                                _buildRadioOption(
                                  title: 'Tender Site Meeting',
                                  subtitle:
                                      'On-site meeting for tender purposes',
                                  value: 'Tender Site Meeting',
                                  groupValue: selectedButtonType,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedButtonType = value;
                                    });
                                  },
                                ),
                                _buildRadioOption(
                                  title: 'Business Site Inspection',
                                  subtitle: 'Inspection of business premises',
                                  value: 'Business Site Inspection',
                                  groupValue: selectedButtonType,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedButtonType = value;
                                    });
                                  },
                                ),
                                _buildRadioOption(
                                  title: 'Client Business Meeting',
                                  subtitle: 'Meeting with clients or partners',
                                  value: 'Client Business Meeting',
                                  groupValue: selectedButtonType,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedButtonType = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Industry Selection Section
                      SlideTransition(
                        position: _slideUpAnimation,
                        child: FadeTransition(
                          opacity: _fadeInAnimation,
                          child: _buildSectionCard(
                            title: 'Industry Selection',
                            icon: Icons.business_outlined,
                            child: _buildIndustryDropdown(),
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
