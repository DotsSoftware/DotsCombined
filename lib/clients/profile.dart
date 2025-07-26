import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../utils/theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  User? user;
  Map<String, dynamic>? userData;
  File? _imageFile;
  String? _uploadedImageUrl;
  String? errorMessage;
  bool isLoading = false;

  bool isEditingFirstName = false;
  bool isEditingSurname = false;
  bool isEditingAddress = false;
  bool isEditingPhoneNumber = false;
  bool isEditingCompanyName = false;
  bool isEditingCompanyRegistration = false;
  bool isEditingVatRegistration = false;

  TextEditingController firstNameController = TextEditingController();
  TextEditingController surnameController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController phoneNumberController = TextEditingController();
  TextEditingController companyNameController = TextEditingController();
  TextEditingController companyRegistrationController = TextEditingController();
  TextEditingController vatRegistrationController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    user = FirebaseAuth.instance.currentUser;
    fetchUserData();
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), 
      end: Offset.zero
    ).animate(
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

  Future<void> fetchUserData() async {
    setState(() => isLoading = true);
    try {
      if (user != null) {
        // Check both 'register' and 'users' collections
        final docRef = FirebaseFirestore.instance
            .collection('users')  // Changed from 'register' to 'users'
            .doc(user!.uid);
        final docSnapshot = await docRef.get();
        
        if (!docSnapshot.exists) {
          // Fallback to 'register' collection if not found in 'users'
          final registerDoc = await FirebaseFirestore.instance
              .collection('register')
              .doc(user!.uid)
              .get();
              
          if (registerDoc.exists) {
            setState(() {
              userData = registerDoc.data();
            });
          }
        } else {
          setState(() {
            userData = docSnapshot.data();
          });
        }

        if (userData != null) {
          setState(() {
            _uploadedImageUrl = userData!['profileImageUrl'];
            firstNameController.text = userData!['firstName'] ?? '';
            surnameController.text = userData!['surname'] ?? '';
            addressController.text = userData!['address'] ?? '';
            phoneNumberController.text = userData!['phoneNumber'] ?? '';
            companyNameController.text = userData!['companyName'] ?? '';
            companyRegistrationController.text = userData!['companyRegistration'] ?? '';
            vatRegistrationController.text = userData!['vatRegistration'] ?? '';
          });
        } else {
          setState(() {
            errorMessage = 'User data not found. Please complete your registration.';
          });
        }
      } else {
        setState(() {
          errorMessage = 'No user is currently signed in.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching user data: ${e.toString()}';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    setState(() => isLoading = true);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error picking image: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null || user == null) return;
    setState(() => isLoading = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user!.uid}.jpg');
      await storageRef.putFile(_imageFile!);
      final downloadUrl = await storageRef.getDownloadURL();
      setState(() {
        _uploadedImageUrl = downloadUrl;
      });
      await FirebaseFirestore.instance
          .collection('register')
          .doc(user!.uid)
          .update({'profileImageUrl': _uploadedImageUrl});
    } catch (e) {
      setState(() {
        errorMessage = 'Error uploading image: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateUserProfile(String field, String value) async {
    if (user == null) {
      setState(() {
        errorMessage = 'No user is currently signed in.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user is currently signed in.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('register')
          .doc(user!.uid)
          .update({field: value});
    } catch (e) {
      setState(() {
        errorMessage = 'Error updating $field: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating $field: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildModernCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    bool isEditing = false,
    bool isPhoneNumber = false,
    VoidCallback? onEditPress,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: isEditing
          ? TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: isPhoneNumber
                  ? TextInputType.phone
                  : TextInputType.text,
            )
          : Row(
              children: [
                if (isPhoneNumber)
                  Image.network(
                    'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Flag_of_South_Africa.svg.png?alt=media&token=1a97d704-78ca-4fde-9d32-1443a800e4e6',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.flag, color: Colors.white, size: 24),
                  ),
                if (isPhoneNumber) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.text.isNotEmpty
                        ? controller.text
                        : 'No information added',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEditableProfileField(
    String fieldName,
    TextEditingController controller,
    String firestoreField,
    bool isEditing,
    VoidCallback onEditPress, {
    bool isPhoneNumber = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                fieldName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    if (isEditing) {
                      await _updateUserProfile(firestoreField, controller.text);
                    }
                    onEditPress();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      isEditing ? 'Save' : 'Edit',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInputField(
            label: fieldName,
            controller: controller,
            isEditing: isEditing,
            isPhoneNumber: isPhoneNumber,
            onEditPress: onEditPress,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
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
                                      size: 30,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Your Profile',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Error Message
                    if (errorMessage != null)
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
                                    errorMessage!,
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

                    // Profile Content
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildModernCard(
                          title: 'Profile Details',
                          icon: Icons.person,
                          child: Column(
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
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
                                                        const Icon(
                                                          Icons.person,
                                                          color: Color(0xFF1E3A8A),
                                                          size: 60,
                                                        ),
                                              )
                                            : const Icon(
                                                Icons.person,
                                                color: Color(0xFF1E3A8A),
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
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            'Upload a Photo',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildEditableProfileField(
                                'First Name(s)',
                                firstNameController,
                                'firstName',
                                isEditingFirstName,
                                () {
                                  setState(() {
                                    isEditingFirstName = !isEditingFirstName;
                                  });
                                },
                              ),
                              _buildEditableProfileField(
                                'Surname',
                                surnameController,
                                'surname',
                                isEditingSurname,
                                () {
                                  setState(() {
                                    isEditingSurname = !isEditingSurname;
                                  });
                                },
                              ),
                              _buildEditableProfileField(
                                'Address',
                                addressController,
                                'address',
                                isEditingAddress,
                                () {
                                  setState(() {
                                    isEditingAddress = !isEditingAddress;
                                  });
                                },
                              ),
                              _buildEditableProfileField(
                                'Phone Number',
                                phoneNumberController,
                                'phoneNumber',
                                isEditingPhoneNumber,
                                () {
                                  setState(() {
                                    isEditingPhoneNumber = !isEditingPhoneNumber;
                                  });
                                },
                                isPhoneNumber: true,
                              ),
                              _buildEditableProfileField(
                                'Company Name',
                                companyNameController,
                                'companyName',
                                isEditingCompanyName,
                                () {
                                  setState(() {
                                    isEditingCompanyName = !isEditingCompanyName;
                                  });
                                },
                              ),
                              _buildEditableProfileField(
                                'Company Registration',
                                companyRegistrationController,
                                'companyRegistration',
                                isEditingCompanyRegistration,
                                () {
                                  setState(() {
                                    isEditingCompanyRegistration = !isEditingCompanyRegistration;
                                  });
                                },
                              ),
                              _buildEditableProfileField(
                                'VAT Registration',
                                vatRegistrationController,
                                'vatRegistration',
                                isEditingVatRegistration,
                                () {
                                  setState(() {
                                    isEditingVatRegistration = !isEditingVatRegistration;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  void dispose() {
    firstNameController.dispose();
    surnameController.dispose();
    addressController.dispose();
    phoneNumberController.dispose();
    companyNameController.dispose();
    companyRegistrationController.dispose();
    vatRegistrationController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
