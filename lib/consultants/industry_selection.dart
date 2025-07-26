import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Banking.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient

class IndustrySelectionPage extends StatefulWidget {
  const IndustrySelectionPage({Key? key}) : super(key: key);

  @override
  _IndustrySelectionPageState createState() => _IndustrySelectionPageState();
}

class _IndustrySelectionPageState extends State<IndustrySelectionPage>
    with TickerProviderStateMixin {
  String? selectedDescription;
  Map<String, Map<String, bool>> industryType = {};
  Map<String, Map<String, Map<String, bool>>> levelSelections = {};
  Map<String, int> totalLevelSelections = {'1': 0, '2': 0, '3': 0};
  final Map<String, int> maxLevelSelections = {'1': 15, '2': 10, '3': 5};
  String? _errorMessage;

  Map<String, String> buttonDescriptions = {
    'Level 1 - Basic Knowledge':
        'Basic knowledge in presenting and gathering of information. With little or no industry-specific experience.',
    'Level 2 - Skilled In Industry':
        'Skilled in the selected industry, to be able to identify, gather and present information. Including those with work experience. Can offer advice and solutions to general issues.',
    'Level 3 - High Level Of Expertise':
        'High level of expertise in the industry, to the level of experienced professionals. Can offer solutions and advice on industry-specific issues, including options and costings, if necessary.',
  };

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeSelections();
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

  void _initializeSelections() {
    industryType = {
      'Agriculture': {'Animal Production': false, 'Crop Production': false},
      'Construction/Engineering': {
        'Building Construction': false,
        'Civil Works': false,
        'Electrical Works': false,
        'Equipment Hire': false,
        'Interior Design': false,
        'Landscaping/Sports Fields': false,
        'Mechanical Engineering': false,
        'Other (Chemistry/Automation/Solar/Biotechnology)': false,
        'Structural Engineering': false,
      },
      'Energy': {
        'Backup Power System': false,
        'Petroleum': false,
        'Solar Generation': false,
      },
      'Environmental': {
        'Conservation': false,
        'Environmental Management': false,
      },
      'Facility Management': {
        'Building Maintenance': false,
        'Cleaning Services': false,
        'Electrical Services': false,
        'HVAC Maintenance': false,
        'Plumbing Services': false,
        'Space Planning': false,
      },
      'Financial Services': {
        'Accountant': false,
        'Auditing': false,
        'Insurance': false,
      },
      'Health': {
        'Healthcare Services': false,
        'Medical Equipment Inspection': false,
      },
      'Legal': {'Legal Consultancy': false},
      'Mining': {'Mining Operations': false, 'Mining Support Services': false},
      'Real Estate': {'Building Inspector': false},
      'Security': {
        'General Security': false,
        'Security Systems & Surveillance': false,
      },
      'Other': {
        'Business Consulting': false,
        'Car Mechanic': false,
        'Marketing': false,
        'Media and Entertainment': false,
      },
    };

    levelSelections = {
      for (var industry in industryType.keys)
        industry: {
          for (var subcategory in industryType[industry]!.keys)
            subcategory: {'1': false, '2': false, '3': false},
        },
    };
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildModernCard({
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
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

  Widget _buildLevelButton(String level, Color color, String descriptionKey) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDescription = selectedDescription == descriptionKey
              ? null
              : descriptionKey;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectedDescription == descriptionKey
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedDescription == descriptionKey
                ? Colors.white.withOpacity(0.8)
                : Colors.white.withOpacity(0.3),
            width: selectedDescription == descriptionKey ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (selectedDescription == descriptionKey)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        buttonDescriptions[descriptionKey]!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
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

  Widget _buildCategorySection(String title, List<Widget> children) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildModernCard(
          title: title,
          icon: Icons.business_outlined,
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildCheckboxWithLevel(
    String title,
    bool? isSubcategorySelected,
    ValueChanged<bool?> onSubcategoryChanged,
    Map<String, bool> levelSelections,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            value: isSubcategorySelected,
            onChanged: onSubcategoryChanged,
            activeColor: Colors.white,
            checkColor: const Color(0xFF1E3A8A),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40.0, right: 16.0),
            child: Wrap(
              spacing: 8.0, // Space between checkboxes horizontally
              runSpacing: 4.0, // Space between rows
              children: levelSelections.keys.map((level) {
                return Row(
                  mainAxisSize: MainAxisSize.min, // Minimize row width
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Checkbox(
                        value: levelSelections[level],
                        onChanged: (bool? newValue) {
                          setState(() {
                            if (isSubcategorySelected == true) {
                              if (newValue == true) {
                                levelSelections.forEach((key, _) {
                                  levelSelections[key] = false;
                                });
                                levelSelections[level] = true;
                                totalLevelSelections[level] =
                                    (totalLevelSelections[level] ?? 0) + 1;
                                if (totalLevelSelections[level]! >
                                    maxLevelSelections[level]!) {
                                  levelSelections[level] = false;
                                  totalLevelSelections[level] =
                                      maxLevelSelections[level]!;
                                  _errorMessage =
                                      'Maximum selections for Level $level reached.';
                                }
                              } else {
                                totalLevelSelections[level] =
                                    (totalLevelSelections[level] ?? 0) - 1;
                              }
                            } else {
                              _errorMessage =
                                  'Please select the subcategory first.';
                            }
                          });
                        },
                        activeColor: Colors.white,
                        checkColor: const Color(0xFF1E3A8A),
                      ),
                    ),
                    Text(
                      'Level $level',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _storeIndustryData() async {
    final User? user = auth.currentUser;
    if (user != null) {
      try {
        final DocumentReference docRef = firestore
            .collection('consultant_register')
            .doc(user.uid);
        List<Map<String, dynamic>> selectedIndustries = [];

        industryType.forEach((industry, subcategories) {
          subcategories.forEach((subcategory, isSelected) {
            if (isSelected) {
              String? selectedLevel;
              levelSelections[industry]?[subcategory]?.forEach((
                level,
                isLevelSelected,
              ) {
                if (isLevelSelected) {
                  selectedLevel = level;
                }
              });

              if (selectedLevel != null) {
                selectedIndustries.add({
                  'type': subcategory,
                  'level': int.parse(selectedLevel!),
                  'category': industry,
                });
              }
            }
          });
        });

        if (selectedIndustries.isNotEmpty) {
          await docRef.set({
            'industries': selectedIndustries,
            'industry_type': selectedIndustries[0]['type'],
            'level': selectedIndustries[0]['level'],
          }, SetOptions(merge: true));

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BankingPage()),
          );
        } else {
          setState(() {
            _errorMessage = 'Please select at least one industry and level.';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error saving selections. Please try again.';
        });
      }
    } else {
      setState(() {
        _errorMessage = 'User not authenticated. Please log in.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
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
                          child: Image.network(
                            'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFF1E3A8A),
                                  size: 40,
                                ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Industry Selection',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
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
                ),

                const SizedBox(height: 32),

                // Level Descriptions
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildModernCard(
                      title: 'Competency Levels',
                      icon: Icons.stars_outlined,
                      child: Column(
                        children: buttonDescriptions.keys.map((level) {
                          return _buildLevelButton(
                            level,
                            level == 'Level 1 - Basic Knowledge'
                                ? Colors.red
                                : level == 'Level 2 - Skilled In Industry'
                                ? Colors.green
                                : Colors.blue,
                            level,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // Industry Sections
                ...industryType.keys.map((industry) {
                  return _buildCategorySection(
                    industry,
                    industryType[industry]!.keys.map((subcategory) {
                      return _buildCheckboxWithLevel(
                        subcategory,
                        industryType[industry]![subcategory],
                        (bool? value) {
                          setState(() {
                            industryType[industry]![subcategory] = value!;
                          });
                        },
                        levelSelections[industry]![subcategory]!,
                      );
                    }).toList(),
                  );
                }).toList(),

                // Error Message
                if (_errorMessage != null)
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
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
                            const Icon(Icons.error_outline, color: Colors.red),
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
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(top: 16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _storeIndustryData,
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
                                  Icons.arrow_forward,
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
                    ),
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
