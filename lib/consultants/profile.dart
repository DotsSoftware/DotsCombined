import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  User? user;
  DocumentSnapshot<Map<String, dynamic>>? userData;
  File? _imageFile;
  String? _uploadedImageUrl;
  List<Map<String, dynamic>> industries = [];
  List<Map<String, String>> uploadedDocuments = [];
  String? _errorMessage;
  bool _isLoading = false;

  List<String> documentTypes = [
    'ID',
    'Passport',
    'Proof of Address',
    'Driver\'s License',
    'Other',
  ];
  String selectedDocumentType = 'Other';

  bool isEditingFirstName = false;
  bool isEditingSurname = false;
  bool isEditingAddress = false;
  bool isEditingPhoneNumber = false;
  bool isEditingCompanyName = false;
  bool isEditingCompanyRegistration = false;
  bool isEditingVatRegistration = false;
  bool isEditingBankName = false;
  bool isEditingBranchCode = false;
  bool isEditingAccountNumber = false;
  bool isEditingAccountType = false;
  bool isEditingAccountHolder = false;

  TextEditingController firstNameController = TextEditingController();
  TextEditingController surnameController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController phoneNumberController = TextEditingController();
  TextEditingController companyNameController = TextEditingController();
  TextEditingController companyRegistrationController = TextEditingController();
  TextEditingController vatRegistrationController = TextEditingController();
  TextEditingController bankNameController = TextEditingController();
  TextEditingController branchCodeController = TextEditingController();
  TextEditingController accountNumberController = TextEditingController();
  TextEditingController accountTypeController = TextEditingController();
  TextEditingController accountHolderController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _initAnimations();
    fetchUserData();
    fetchUploadedDocuments();
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
    firstNameController.dispose();
    surnameController.dispose();
    addressController.dispose();
    phoneNumberController.dispose();
    companyNameController.dispose();
    companyRegistrationController.dispose();
    vatRegistrationController.dispose();
    bankNameController.dispose();
    branchCodeController.dispose();
    accountNumberController.dispose();
    accountTypeController.dispose();
    accountHolderController.dispose();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    if (user != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        final docRef = FirebaseFirestore.instance
            .collection('consultant_register')
            .doc(user!.uid);
        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          setState(() {
            userData = docSnapshot;
            _uploadedImageUrl = userData!.data()?['profileImageUrl'];
            firstNameController.text = userData!.data()?['firstName'] ?? '';
            surnameController.text = userData!.data()?['surname'] ?? '';
            addressController.text = userData!.data()?['address'] ?? '';
            phoneNumberController.text = userData!.data()?['phoneNumber'] ?? '';
            companyNameController.text = userData!.data()?['companyName'] ?? '';
            companyRegistrationController.text =
                userData!.data()?['companyRegistration'] ?? '';
            vatRegistrationController.text =
                userData!.data()?['vatRegistration'] ?? '';
            bankNameController.text = userData!.data()?['Bank Name'] ?? '';
            branchCodeController.text = userData!.data()?['Branch Code'] ?? '';
            accountNumberController.text =
                userData!.data()?['Account Number'] ?? '';
            accountTypeController.text =
                userData!.data()?['Account Type'] ?? '';
            accountHolderController.text =
                userData!.data()?['Account Holder'] ?? '';
            var industriesData = userData!.data()?['industries'];
            if (industriesData != null && industriesData is List) {
              industries = List<Map<String, dynamic>>.from(industriesData);
            }
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to fetch user data: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> fetchUploadedDocuments() async {
    if (user != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('consultant_side')
            .doc(user!.uid)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            uploadedDocuments.clear();
            _addDocumentIfExists(docSnapshot, 'idUrl', 'ID', 'idFileName');
            _addDocumentIfExists(
              docSnapshot,
              'passportUrl',
              'Passport',
              'passportFileName',
            );
            _addDocumentIfExists(
              docSnapshot,
              'addressProofUrl',
              'Proof of Address',
              'addressProofFileName',
            );
            _addDocumentIfExists(
              docSnapshot,
              'driversLicenseUrl',
              'Driver\'s License',
              'driversLicenseFileName',
            );

            if (docSnapshot.data()!.containsKey('additionalFiles')) {
              List<dynamic> additionalFiles = docSnapshot['additionalFiles'];
              for (var file in additionalFiles) {
                uploadedDocuments.add({
                  'url': file['url'],
                  'name': file['name'],
                  'type': 'Other',
                });
              }
            }
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to fetch documents: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _addDocumentIfExists(
    DocumentSnapshot docSnapshot,
    String urlKey,
    String type,
    String nameKey,
  ) {
    final url = docSnapshot[urlKey];
    final name = docSnapshot[nameKey] ?? type;
    if (url != null && url.isNotEmpty) {
      uploadedDocuments.add({'url': url, 'name': name, 'type': type});
    }
  }

  Future<void> _uploadNewDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName =
            '${user!.uid}/additional_docs/${DateTime.now().millisecondsSinceEpoch}';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        await storageRef.putFile(file);
        String fileUrl = await storageRef.getDownloadURL();

        final docRef = FirebaseFirestore.instance
            .collection('consultant_side')
            .doc(user!.uid);

        final currentDoc = await docRef.get();
        List<dynamic> additionalFiles =
            currentDoc.data()?['additionalFiles'] ?? [];
        additionalFiles.add({'url': fileUrl, 'name': result.files.single.name});

        await docRef.set({
          'additionalFiles': additionalFiles,
        }, SetOptions(merge: true));

        setState(() {
          uploadedDocuments.add({
            'url': fileUrl,
            'name': result.files.single.name,
            'type': selectedDocumentType,
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Document uploaded successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Future<void> _removeDocument(Map<String, String> document) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final docRef = FirebaseFirestore.instance
          .collection('consultant_side')
          .doc(user!.uid);

      final currentDoc = await docRef.get();
      List<dynamic> additionalFiles =
          currentDoc.data()?['additionalFiles'] ?? [];

      additionalFiles.removeWhere(
        (file) =>
            file['url'] == document['url'] && file['name'] == document['name'],
      );

      await docRef.set({
        'additionalFiles': additionalFiles,
      }, SetOptions(merge: true));

      final storageRef = FirebaseStorage.instance.refFromURL(document['url']!);
      await storageRef.delete();

      setState(() {
        uploadedDocuments.remove(document);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Document removed successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to remove document: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
        await _uploadImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to upload image: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null || user == null) return;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user!.uid}.jpg');
      await storageRef.putFile(_imageFile!);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('consultant_register')
          .doc(user!.uid)
          .update({'profileImageUrl': downloadUrl});

      setState(() {
        _uploadedImageUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile image uploaded successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to upload image: $e';
      });
    }
  }

  Future<void> _updateUserProfile(String field, String value) async {
    if (user != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await FirebaseFirestore.instance
            .collection('consultant_register')
            .doc(user!.uid)
            .update({field: value.trim()});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$field updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to update $field: $e';
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

  Widget _buildModernTextField({
    required String label,
    required TextEditingController controller,
    bool isEditing = false,
    bool isPhoneNumber = false,
    VoidCallback? onEditPress,
    required String firestoreField,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: isEditing
                ? TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: isPhoneNumber
                        ? TextInputType.phone
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                    ),
                  )
                : Text(
                    controller.text.isNotEmpty
                        ? controller.text
                        : 'Not provided',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isEditing) {
                  _updateUserProfile(firestoreField, controller.text);
                }
                onEditPress?.call();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isEditing ? Icons.save : Icons.edit,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndustriesSection() {
    return _buildModernCard(
      title: 'Industry Information',
      icon: Icons.business_outlined,
      child: industries.isEmpty
          ? Text(
              'No industries specified',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            )
          : Column(
              children: industries.map((industry) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getLevelColor(industry['level']),
                        child: Text(
                          'L${industry['level']}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              industry['type'] ?? 'Unknown Industry',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Category: ${industry['category'] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Level: ${industry['level'] ?? 'N/A'}',
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
                );
              }).toList(),
            ),
    );
  }

  Widget _documentsSection() {
    return _buildModernCard(
      title: 'Uploaded Documents',
      icon: Icons.upload_file_outlined,
      child: Column(
        children: [
          uploadedDocuments.isEmpty
              ? Text(
                  'No documents uploaded yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                )
              : Column(
                  children: uploadedDocuments.map((document) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  document['name'] ?? 'Unnamed Document',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  document['type'] ?? 'Unspecified Type',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _removeDocument(document),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.delete,
                                  color: Colors.red.withOpacity(0.8),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedDocumentType,
                  decoration: InputDecoration(
                    labelText: 'Document Type',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                  ),
                  dropdownColor: Colors.white.withOpacity(0.9),
                  style: const TextStyle(color: Colors.white),
                  items: documentTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDocumentType = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _uploadNewDocument,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
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
            ],
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(int? level) {
    switch (level) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: _isLoading || userData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading profile...',
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
                      // Header with Profile Picture
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _uploadedImageUrl != null
                                      ? Image.network(
                                          _uploadedImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                                    Icons.person,
                                                    color: Colors.grey.shade600,
                                                    size: 60,
                                                  ),
                                        )
                                      : Icon(
                                          Icons.person,
                                          color: Colors.grey.shade600,
                                          size: 60,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _pickImage,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'Upload a photo',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                '${firstNameController.text} ${surnameController.text}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                user?.email ?? 'No email provided',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w300,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Personal Information
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: 'Personal Information',
                            icon: Icons.person_outline,
                            child: Column(
                              children: [
                                _buildModernTextField(
                                  label: 'First Name(s)',
                                  controller: firstNameController,
                                  isEditing: isEditingFirstName,
                                  firestoreField: 'firstName',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingFirstName = !isEditingFirstName;
                                    });
                                  },
                                ),
                                _buildModernTextField(
                                  label: 'Surname',
                                  controller: surnameController,
                                  isEditing: isEditingSurname,
                                  firestoreField: 'surname',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingSurname = !isEditingSurname;
                                    });
                                  },
                                ),
                                _buildModernTextField(
                                  label: 'Address',
                                  controller: addressController,
                                  isEditing: isEditingAddress,
                                  firestoreField: 'address',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingAddress = !isEditingAddress;
                                    });
                                  },
                                ),
                                _buildModernTextField(
                                  label: 'Phone Number',
                                  controller: phoneNumberController,
                                  isEditing: isEditingPhoneNumber,
                                  isPhoneNumber: true,
                                  firestoreField: 'phoneNumber',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingPhoneNumber =
                                          !isEditingPhoneNumber;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Company Information
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: 'Company Information',
                            icon: Icons.business_outlined,
                            child: Column(
                              children: [
                                _buildModernTextField(
                                  label: 'Company Name',
                                  controller: companyNameController,
                                  isEditing: isEditingCompanyName,
                                  firestoreField: 'companyName',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingCompanyName =
                                          !isEditingCompanyName;
                                    });
                                  },
                                ),
                                _buildModernTextField(
                                  label: 'Company Registration',
                                  controller: companyRegistrationController,
                                  isEditing: isEditingCompanyRegistration,
                                  firestoreField: 'companyRegistration',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingCompanyRegistration =
                                          !isEditingCompanyRegistration;
                                    });
                                  },
                                ),
                                _buildModernTextField(
                                  label: 'VAT Registration',
                                  controller: vatRegistrationController,
                                  isEditing: isEditingVatRegistration,
                                  firestoreField: 'vatRegistration',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingVatRegistration =
                                          !isEditingVatRegistration;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Banking Details
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: 'Banking Details',
                            icon: Icons.account_balance_outlined,
                            child: Column(
                              children: [
                                _buildModernTextField(
                                  label: 'Bank Name',
                                  controller: bankNameController,
                                  isEditing: isEditingBankName,
                                  firestoreField: 'Bank Name',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingBankName = !isEditingBankName;
                                    });
                                  },
                                ),
                                _buildModernTextField(
                                  label: 'Branch Code',
                                  controller: branchCodeController,
                                  isEditing: isEditingBranchCode,
                                  firestoreField: 'Branch Code',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingBranchCode =
                                          !isEditingBranchCode;
                                    });
                                  },
                                ),
                                _buildModernTextField(
                                  label: 'Account Number',
                                  controller: accountNumberController,
                                  isEditing: isEditingAccountNumber,
                                  firestoreField: 'Account Number',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingAccountNumber =
                                          !isEditingAccountNumber;
                                    });
                                  },
                                ),
                                _buildModernTextField(
                                  label: 'Account Type',
                                  controller: accountTypeController,
                                  isEditing: isEditingAccountType,
                                  firestoreField: 'Account Type',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingAccountType =
                                          !isEditingAccountType;
                                    });
                                  },
                                ),
                                _buildModernTextField(
                                  label: 'Account Holder',
                                  controller: accountHolderController,
                                  isEditing: isEditingAccountHolder,
                                  firestoreField: 'Account Holder',
                                  onEditPress: () {
                                    setState(() {
                                      isEditingAccountHolder =
                                          !isEditingAccountHolder;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Industries Section
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildIndustriesSection(),
                        ),
                      ),

                      // Documents Section
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _documentsSection(),
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

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
