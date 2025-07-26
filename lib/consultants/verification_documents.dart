import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'terms.dart';
import 'consultant_dashboard.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient

class VerificationDocumentsPage extends StatefulWidget {
  const VerificationDocumentsPage({Key? key}) : super(key: key);

  @override
  _VerificationDocumentsPageState createState() =>
      _VerificationDocumentsPageState();
}

class _VerificationDocumentsPageState extends State<VerificationDocumentsPage>
    with TickerProviderStateMixin {
  bool isSouthAfricanCitizen = false;
  bool willDriveToJobs = false;
  String? idUrl;
  String? passportUrl;
  String? addressProofUrl;
  String? driversLicenseUrl;
  String? idFileName;
  String? passportFileName;
  String? addressProofFileName;
  String? driversLicenseFileName;
  List<String> additionalFileUrls = [];
  List<String> additionalFileNames = [];
  String? _errorMessage;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  Map<String, Map<String, bool>> industryType = {
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
    'Environmental': {'Conservation': false, 'Environmental Management': false},
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

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchData();
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('consultant_side')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            isSouthAfricanCitizen =
                docSnapshot['isSouthAfricanCitizen'] ?? false;
            willDriveToJobs = docSnapshot['willDriveToJobs'] ?? false;
            idUrl = docSnapshot['idUrl'];
            passportUrl = docSnapshot['passportUrl'];
            addressProofUrl = docSnapshot['addressProofUrl'];
            driversLicenseUrl = docSnapshot['driversLicenseUrl'];
            idFileName = docSnapshot['idFileName'];
            passportFileName = docSnapshot['passportFileName'];
            addressProofFileName = docSnapshot['addressProofFileName'];
            driversLicenseFileName = docSnapshot['driversLicenseFileName'];

            if (docSnapshot.data()!.containsKey('additionalFiles')) {
              List<dynamic> additionalFiles = docSnapshot['additionalFiles'];
              additionalFileUrls = additionalFiles
                  .map((file) => file['url'] as String)
                  .toList();
              additionalFileNames = additionalFiles
                  .map((file) => file['name'] as String)
                  .toList();
            }

            // Fetch selected industries
            if (docSnapshot.data()!.containsKey('selectedIndustries')) {
              Map<String, dynamic> selectedIndustries =
                  Map<String, dynamic>.from(docSnapshot['selectedIndustries']);
              selectedIndustries.forEach((industry, categories) {
                if (industryType.containsKey(industry)) {
                  Map<String, dynamic> selectedCategories =
                      Map<String, dynamic>.from(categories);
                  selectedCategories.forEach((category, isSelected) {
                    if (industryType[industry]!.containsKey(category)) {
                      industryType[industry]![category] = isSelected;
                    }
                  });
                }
              });
            }
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to fetch data: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  Widget _toggleButton(String label, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => onChanged(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: value ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  child: Text(
                    'Yes',
                    style: TextStyle(
                      color: value ? const Color(0xFF1E3A8A) : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onChanged(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: !value ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  child: Text(
                    'No',
                    style: TextStyle(
                      color: !value ? const Color(0xFF1E3A8A) : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uploadButton(
    String label,
    Function(String, String) onFileUploaded,
    String? fileName,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _uploadFile(label, onFileUploaded),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fileName ?? label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(
                        fileName != null ? 1.0 : 0.7,
                      ),
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.upload_file, color: Colors.white.withOpacity(0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndustryDocuments() {
    List<Widget> industryWidgets = [];

    industryType.forEach((industry, categories) {
      bool hasSelectedCategories = categories.values.any(
        (isSelected) => isSelected,
      );
      if (hasSelectedCategories) {
        List<Widget> categoryWidgets = [];
        categories.forEach((category, isSelected) {
          if (isSelected) {
            categoryWidgets.add(
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  category,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                trailing: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _uploadIndustryDocument(industry, category),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.upload_file,
                            color: const Color(0xFF1E3A8A),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Upload',
                            style: TextStyle(
                              color: const Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        });

        if (categoryWidgets.isNotEmpty) {
          industryWidgets.add(
            _buildModernCard(
              title: industry,
              icon: Icons.business_outlined,
              child: Column(children: categoryWidgets),
            ),
          );
        }
      }
    });

    return _buildModernCard(
      title: 'Industry-Specific Documents',
      icon: Icons.description_outlined,
      child: industryWidgets.isEmpty
          ? Text(
              'No industries selected',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            )
          : Column(children: industryWidgets),
    );
  }

  Future<void> _uploadFile(
    String label,
    Function(String, String) onFileUploaded,
  ) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName =
            '${FirebaseAuth.instance.currentUser!.uid}/$label/${DateTime.now().millisecondsSinceEpoch}';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        await storageRef.putFile(file);
        String fileUrl = await storageRef.getDownloadURL();
        onFileUploaded(fileUrl, result.files.single.name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label uploaded successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to upload $label: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadIndustryDocument(String industry, String category) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName =
            '${FirebaseAuth.instance.currentUser!.uid}/industry_docs/$industry/$category/${DateTime.now().millisecondsSinceEpoch}';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        await storageRef.putFile(file);
        String fileUrl = await storageRef.getDownloadURL();

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('consultant_side')
              .doc(user.uid)
              .update({
                'industry_documents': FieldValue.arrayUnion([
                  {
                    'industry': industry,
                    'category': category,
                    'url': fileUrl,
                    'name': result.files.single.name,
                    'uploadedAt': FieldValue.serverTimestamp(),
                  },
                ]),
              });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$category document uploaded successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to upload document: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        List<Map<String, String>> additionalFiles = [];
        for (int i = 0; i < additionalFileUrls.length; i++) {
          additionalFiles.add({
            'url': additionalFileUrls[i],
            'name': additionalFileNames[i],
          });
        }

        await FirebaseFirestore.instance
            .collection('consultant_side')
            .doc(user.uid)
            .set({
              'isSouthAfricanCitizen': isSouthAfricanCitizen,
              'willDriveToJobs': willDriveToJobs,
              'idUrl': idUrl,
              'passportUrl': passportUrl,
              'addressProofUrl': addressProofUrl,
              'driversLicenseUrl': driversLicenseUrl,
              'idFileName': idFileName,
              'passportFileName': passportFileName,
              'addressProofFileName': addressProofFileName,
              'driversLicenseFileName': driversLicenseFileName,
              'additionalFiles': additionalFiles,
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Error saving data: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = 'User not authenticated. Please log in.';
      });
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Document Submission Received',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you for submitting your documents. Our verification team will carefully review your information. '
                'Once verified, you will be able to fully access the DOTS platform and receive job requests. '
                'We appreciate your patience during this process.',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TermsPage()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.white, Color(0xFFF0F0F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Understood',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
                        'Processing...',
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
                                'Verification Documents',
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

                      // Identity Documents
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: 'Identity Documents',
                            icon: Icons.person_outline,
                            child: Column(
                              children: [
                                _toggleButton(
                                  'Are you a South African citizen?',
                                  isSouthAfricanCitizen,
                                  (value) {
                                    setState(() {
                                      isSouthAfricanCitizen = value;
                                    });
                                  },
                                ),
                                _uploadButton('Upload Your Valid ID', (
                                  url,
                                  fileName,
                                ) {
                                  setState(() {
                                    idUrl = url;
                                    idFileName = fileName;
                                  });
                                }, idFileName),
                                _uploadButton('Upload Your Valid Passport', (
                                  url,
                                  fileName,
                                ) {
                                  setState(() {
                                    passportUrl = url;
                                    passportFileName = fileName;
                                  });
                                }, passportFileName),
                                _uploadButton('Upload Proof of Address', (
                                  url,
                                  fileName,
                                ) {
                                  setState(() {
                                    addressProofUrl = url;
                                    addressProofFileName = fileName;
                                  });
                                }, addressProofFileName),
                                _toggleButton(
                                  'Are you going to be driving to jobs?',
                                  willDriveToJobs,
                                  (value) {
                                    setState(() {
                                      willDriveToJobs = value;
                                    });
                                  },
                                ),
                                if (willDriveToJobs)
                                  _uploadButton(
                                    'Upload Your Driver\'s License',
                                    (url, fileName) {
                                      setState(() {
                                        driversLicenseUrl = url;
                                        driversLicenseFileName = fileName;
                                      });
                                    },
                                    driversLicenseFileName,
                                  ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      _uploadFile('Additional Document', (
                                        url,
                                        fileName,
                                      ) {
                                        setState(() {
                                          additionalFileUrls.add(url);
                                          additionalFileNames.add(fileName);
                                        });
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Add More Documents',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
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

                      // Uploaded Documents
                      if (idFileName != null ||
                          passportFileName != null ||
                          addressProofFileName != null ||
                          driversLicenseFileName != null ||
                          additionalFileNames.isNotEmpty)
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildModernCard(
                              title: 'Uploaded Documents',
                              icon: Icons.upload_file_outlined,
                              child: Column(
                                children: [
                                  if (idFileName != null)
                                    _uploadedDocumentItem(
                                      'Uploaded ID:',
                                      idFileName!,
                                    ),
                                  if (passportFileName != null)
                                    _uploadedDocumentItem(
                                      'Uploaded Passport:',
                                      passportFileName!,
                                    ),
                                  if (addressProofFileName != null)
                                    _uploadedDocumentItem(
                                      'Proof of Address:',
                                      addressProofFileName!,
                                    ),
                                  if (driversLicenseFileName != null)
                                    _uploadedDocumentItem(
                                      'Driver\'s License:',
                                      driversLicenseFileName!,
                                    ),
                                  for (
                                    int i = 0;
                                    i < additionalFileNames.length;
                                    i++
                                  )
                                    _uploadedDocumentItem(
                                      'Additional File:',
                                      additionalFileNames[i],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Industry Documents
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildIndustryDocuments(),
                        ),
                      ),

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

                      // Save & Proceed Button
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            margin: const EdgeInsets.only(top: 16),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  await _saveData();
                                  _showVerificationDialog();
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
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
                                        'Save & Proceed',
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

                      // Save and Finish Later
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            margin: const EdgeInsets.only(top: 16),
                            child: TextButton(
                              onPressed: () async {
                                await _saveData();
                                _showVerificationDialog();
                              },
                              child: Text(
                                'Save and finish this later',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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

  Widget _uploadedDocumentItem(String label, String fileName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
