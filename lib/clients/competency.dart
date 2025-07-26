import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient
import 'dashboard.dart';
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

class _CompetencyPageState extends State<CompetencyPage>
    with TickerProviderStateMixin {
  String? errorMessage;
  String? selectedCompetencyType;
  String? selectedDistanceType;
  String? jobDescription = 'Select Job Description';
  double totalPrice = 0.0;
  double vatAmount = 0.0;
  bool isForMyself = true;
  int _availableConsultantCount = 0;
  String? _industryType;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Map<String, String> buttonDescriptions = {
    'Level 1 - Basic Knowledge':
        'Basic knowledge in presenting and gathering information. Limited industry-specific experience.',
    'Level 2 - Skilled In Industry':
        'Skilled in the selected industry, capable of identifying, gathering, and presenting information. Includes work experience and general advice.',
    'Level 3 - High Level Of Expertise':
        'High expertise in the industry, offering solutions and advice on complex issues, including options and costings.',
  };

  static const Map<String, String> competencyValues = {
    'Level 1 - Basic Knowledge': '5.00',
    'Level 2 - Skilled In Industry': '9.50',
    'Level 3 - High Level Of Expertise': '21.50',
  };

  static const Map<String, String> publicTransportValues = {
    'Local - Within a 50km Radius': '1.50',
    'Regional - Within a 300km Radius': '4.00',
    'National - Within a 1500km Radius': '60.50',
  };

  static const Map<String, String> ownVehicleValues = {
    'Local - Within a 50km Radius': '4.50',
    'Regional - Within a 300km Radius': '14.00',
    'Provincial - Within a 500km Radius': '19.00',
    'Interprovincial - Within a 1000km Radius': '31.25',
    'National - Within a 1500km Radius': '109.50',
  };

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchIndustryAndConsultants();
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

  Future<void> _fetchIndustryAndConsultants() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        errorMessage = 'Please log in to continue';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to continue'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage()),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String industryType = widget.industryType;
      if (industryType.isEmpty) {
        QuerySnapshot clientRequestSnapshot = await _firestore
            .collection('selection')
            .doc(user.uid)
            .collection('requests')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (clientRequestSnapshot.docs.isNotEmpty) {
          final latestRequest = clientRequestSnapshot.docs.first;
          industryType =
              (latestRequest.data() as Map<String, dynamic>)['industry_type'] ??
              '';
        }
      }

      QuerySnapshot consultantSnapshot = await _firestore
          .collection('consultant_register')
          .where('industry_type', isEqualTo: industryType)
          .get();

      setState(() {
        _industryType = industryType.isNotEmpty ? industryType : null;
        _availableConsultantCount = consultantSnapshot.docs.length;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching data: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotalPrice() {
    double competencyPrice = selectedCompetencyType != null
        ? double.parse(competencyValues[selectedCompetencyType] ?? '0.0')
        : 0.0;

    double distancePrice = selectedDistanceType != null
        ? double.parse(
            isForMyself
                ? publicTransportValues[selectedDistanceType] ?? '0.0'
                : ownVehicleValues[selectedDistanceType] ?? '0.0',
          )
        : 0.0;

    double totalPriceExcludingVAT = competencyPrice + distancePrice;
    double vat = totalPriceExcludingVAT * 0.15;
    double totalPrice = totalPriceExcludingVAT + vat;

    setState(() {
      this.totalPrice = totalPrice;
      this.vatAmount = vat;
    });
  }

  void _selectCompetencyButton(String type) {
    setState(() {
      selectedCompetencyType = selectedCompetencyType == type ? null : type;
      _calculateTotalPrice();
    });
  }

  void _selectDistanceButton(String type) {
    setState(() {
      selectedDistanceType = selectedDistanceType == type ? null : type;
      _calculateTotalPrice();
    });
  }

  Future<void> _storeDataAndNavigate() async {
    if (_industryType == null || _industryType!.isEmpty) {
      setState(() {
        errorMessage = 'Industry type is missing';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Industry type is missing'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        errorMessage = 'Please log in to continue';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to continue'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = user.uid;
      final userEmail = user.email;

      final transactionData = {
        'total_price': totalPrice,
        'vat_amount': vatAmount,
        'timestamp': FieldValue.serverTimestamp(),
        'client_id': userId,
        'client_email': userEmail,
        'industry_type': _industryType,
        'request_type': widget.requestType,
        'selected_competency': selectedCompetencyType,
        'selected_distance': selectedDistanceType,
        'job_description': jobDescription,
      };

      // Store in users/transactions
      final transactionRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .add(transactionData);

      // Store in integrated collection
      if (userEmail != null) {
        final transactionDataForArray = {
          ...transactionData,
          'timestamp': DateTime.now().toIso8601String(),
        };

        final integratedDoc = await _firestore
            .collection('integrated')
            .doc(userEmail)
            .get();
        List<dynamic> existingTransactions =
            integratedDoc.data()?['transactions'] ?? [];

        bool dataExists = existingTransactions.any(
          (transaction) =>
              transaction['selected_competency'] == selectedCompetencyType &&
              transaction['selected_distance'] == selectedDistanceType &&
              transaction['job_description'] == jobDescription,
        );

        if (!dataExists) {
          await _firestore.collection('integrated').doc(userEmail).set({
            'transactions': FieldValue.arrayUnion([transactionDataForArray]),
          }, SetOptions(merge: true));
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SearchPage(
            requestType: selectedCompetencyType ?? '',
            industryType: _industryType!,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error storing data: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error storing data: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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

  Widget _buildSkillLevelButton(String title, String value) {
    return GestureDetector(
      onTap: () => _selectCompetencyButton(title),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectedCompetencyType == title
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedCompetencyType == title
                ? const Color(0xFF1E3A8A)
                : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selectedCompetencyType == title
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
                Text(
                  'R$value',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: selectedCompetencyType == title
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            if (selectedCompetencyType == title) ...[
              const SizedBox(height: 8),
              Text(
                buttonDescriptions[title]!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceButton(String title, String value) {
    return GestureDetector(
      onTap: () => _selectDistanceButton(title),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectedDistanceType == title
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedDistanceType == title
                ? const Color(0xFF1E3A8A)
                : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: selectedDistanceType == title
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
            Text(
              'R$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selectedDistanceType == title
                    ? Colors.white
                    : Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                isForMyself = true;
                selectedDistanceType = null;
                _calculateTotalPrice();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isForMyself
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isForMyself
                      ? const Color(0xFF1E3A8A)
                      : Colors.white.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Public Transport',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isForMyself
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                isForMyself = false;
                selectedDistanceType = null;
                _calculateTotalPrice();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: !isForMyself
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !isForMyself
                      ? const Color(0xFF1E3A8A)
                      : Colors.white.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Own Vehicle',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: !isForMyself
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableConsultants() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _availableConsultantCount > 0
            ? Colors.white.withOpacity(0.2)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _availableConsultantCount > 0
              ? Colors.white.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Available Consultants',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_availableConsultantCount',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_industryType != null)
            Text(
              'Industry: $_industryType',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          if (_availableConsultantCount == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No consultants available for this industry',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade300,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalPriceDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Total Price',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'R${totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'VAT (15%): R${vatAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    bool isEnabled =
        _availableConsultantCount > 0 &&
        selectedCompetencyType != null &&
        selectedDistanceType != null &&
        _industryType != null &&
        _industryType!.isNotEmpty;

    return Column(
      children: [
        GestureDetector(
          onTap: isEnabled ? _storeDataAndNavigate : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: isEnabled
                  ? const LinearGradient(
                      colors: [Colors.white, Color(0xFFF0F0F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isEnabled ? null : Colors.grey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              'Accept',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isEnabled
                    ? const Color(0xFF1E3A8A)
                    : Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        ),
        if (!isEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _getSubmitButtonMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade300, fontSize: 14),
            ),
          ),
      ],
    );
  }

  String _getSubmitButtonMessage() {
    List<String> messages = [];
    if (_industryType == null || _industryType!.isEmpty) {
      messages.add('Industry type is missing');
    }
    if (_availableConsultantCount == 0) {
      messages.add('No consultants available for this industry');
    }
    if (selectedCompetencyType == null) {
      messages.add('Please select a competency level');
    }
    if (selectedDistanceType == null) {
      messages.add('Please select a distance range');
    }
    return messages.join('\n');
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
                        'Loading...',
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
                                  'Consultant Competency',
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

                      // Competency Selection
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: 'Level of Competency',
                            icon: Icons.person,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select the desired expertise level for your consultant',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildSkillLevelButton(
                                  'Level 1 - Basic Knowledge',
                                  '5.00',
                                ),
                                _buildSkillLevelButton(
                                  'Level 2 - Skilled In Industry',
                                  '9.50',
                                ),
                                _buildSkillLevelButton(
                                  'Level 3 - High Level Of Expertise',
                                  '21.50',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Travel Requirements
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: 'Travel Requirements',
                            icon: Icons.directions_car,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select the transportation method and distance range',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTransportToggle(),
                                const SizedBox(height: 16),
                                if (isForMyself) ...[
                                  _buildDistanceButton(
                                    'Local - Within a 50km Radius',
                                    '1.50',
                                  ),
                                  _buildDistanceButton(
                                    'Regional - Within a 300km Radius',
                                    '4.00',
                                  ),
                                  _buildDistanceButton(
                                    'National - Within a 1500km Radius',
                                    '62.50',
                                  ),
                                ] else ...[
                                  _buildDistanceButton(
                                    'Local - Within a 50km Radius',
                                    '4.50',
                                  ),
                                  _buildDistanceButton(
                                    'Regional - Within a 300km Radius',
                                    '14.00',
                                  ),
                                  _buildDistanceButton(
                                    'Provincial - Within a 500km Radius',
                                    '19.00',
                                  ),
                                  _buildDistanceButton(
                                    'Interprovincial - Within a 1000km Radius',
                                    '31.25',
                                  ),
                                  _buildDistanceButton(
                                    'National - Within a 1500km Radius',
                                    '109.50',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Available Consultants
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildAvailableConsultants(),
                        ),
                      ),

                      // Total Price
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildTotalPriceDisplay(),
                        ),
                      ),

                      // Submit Button
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildSubmitButton(),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient
import 'dashboard.dart';
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

class _CompetencyPageState extends State<CompetencyPage>
    with TickerProviderStateMixin {
  String? errorMessage;
  String? selectedCompetencyType;
  String? selectedDistanceType;
  String? jobDescription = 'Select Job Description';
  double totalPrice = 0.0;
  double vatAmount = 0.0;
  bool isForMyself = true;
  int _availableConsultantCount = 0;
  String? _industryType;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Map<String, String> buttonDescriptions = {
    'Level 1 - Basic Knowledge':
        'Basic knowledge in presenting and gathering information. Limited industry-specific experience.',
    'Level 2 - Skilled In Industry':
        'Skilled in the selected industry, capable of identifying, gathering, and presenting information. Includes work experience and general advice.',
    'Level 3 - High Level Of Expertise':
        'High expertise in the industry, offering solutions and advice on complex issues, including options and costings.',
  };

  static const Map<String, String> competencyValues = {
    'Level 1 - Basic Knowledge': '500.00',
    'Level 2 - Skilled In Industry': '937.50',
    'Level 3 - High Level Of Expertise': '2187.50',
  };

  static const Map<String, String> publicTransportValues = {
    'Local - Within a 50km Radius': '187.50',
    'Regional - Within a 300km Radius': '475.00',
    'National - Within a 1500km Radius': '6250.50',
  };

  static const Map<String, String> ownVehicleValues = {
    'Local - Within a 50km Radius': '437.50',
    'Regional - Within a 300km Radius': '1450.00',
    'Provincial - Within a 500km Radius': '1950.00',
    'Interprovincial - Within a 1000km Radius': '3106.25',
    'National - Within a 1500km Radius': '10937.50',
  };

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchIndustryAndConsultants();
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

  Future<void> _fetchIndustryAndConsultants() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        errorMessage = 'Please log in to continue';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to continue'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage()),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String industryType = widget.industryType;
      if (industryType.isEmpty) {
        QuerySnapshot clientRequestSnapshot = await _firestore
            .collection('selection')
            .doc(user.uid)
            .collection('requests')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (clientRequestSnapshot.docs.isNotEmpty) {
          final latestRequest = clientRequestSnapshot.docs.first;
          industryType =
              (latestRequest.data() as Map<String, dynamic>)['industry_type'] ??
              '';
        }
      }

      QuerySnapshot consultantSnapshot = await _firestore
          .collection('consultant_register')
          .where('industry_type', isEqualTo: industryType)
          .get();

      setState(() {
        _industryType = industryType.isNotEmpty ? industryType : null;
        _availableConsultantCount = consultantSnapshot.docs.length;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching data: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotalPrice() {
    double competencyPrice = selectedCompetencyType != null
        ? double.parse(competencyValues[selectedCompetencyType] ?? '0.0')
        : 0.0;

    double distancePrice = selectedDistanceType != null
        ? double.parse(
            isForMyself
                ? publicTransportValues[selectedDistanceType] ?? '0.0'
                : ownVehicleValues[selectedDistanceType] ?? '0.0',
          )
        : 0.0;

    double totalPriceExcludingVAT = competencyPrice + distancePrice;
    double vat = totalPriceExcludingVAT * 0.15;
    double totalPrice = totalPriceExcludingVAT + vat;

    setState(() {
      this.totalPrice = totalPrice;
      this.vatAmount = vat;
    });
  }

  void _selectCompetencyButton(String type) {
    setState(() {
      selectedCompetencyType = selectedCompetencyType == type ? null : type;
      _calculateTotalPrice();
    });
  }

  void _selectDistanceButton(String type) {
    setState(() {
      selectedDistanceType = selectedDistanceType == type ? null : type;
      _calculateTotalPrice();
    });
  }

  Future<void> _storeDataAndNavigate() async {
    if (_industryType == null || _industryType!.isEmpty) {
      setState(() {
        errorMessage = 'Industry type is missing';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Industry type is missing'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        errorMessage = 'Please log in to continue';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to continue'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = user.uid;
      final userEmail = user.email;

      final transactionData = {
        'total_price': totalPrice,
        'vat_amount': vatAmount,
        'timestamp': FieldValue.serverTimestamp(),
        'client_id': userId,
        'client_email': userEmail,
        'industry_type': _industryType,
        'request_type': widget.requestType,
        'selected_competency': selectedCompetencyType,
        'selected_distance': selectedDistanceType,
        'job_description': jobDescription,
      };

      // Store in users/transactions
      final transactionRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .add(transactionData);

      // Store in integrated collection
      if (userEmail != null) {
        final transactionDataForArray = {
          ...transactionData,
          'timestamp': DateTime.now().toIso8601String(),
        };

        final integratedDoc = await _firestore
            .collection('integrated')
            .doc(userEmail)
            .get();
        List<dynamic> existingTransactions =
            integratedDoc.data()?['transactions'] ?? [];

        bool dataExists = existingTransactions.any(
          (transaction) =>
              transaction['selected_competency'] == selectedCompetencyType &&
              transaction['selected_distance'] == selectedDistanceType &&
              transaction['job_description'] == jobDescription,
        );

        if (!dataExists) {
          await _firestore.collection('integrated').doc(userEmail).set({
            'transactions': FieldValue.arrayUnion([transactionDataForArray]),
          }, SetOptions(merge: true));
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SearchPage(
            requestType: selectedCompetencyType ?? '',
            industryType: _industryType!,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error storing data: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error storing data: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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

  Widget _buildSkillLevelButton(String title, String value) {
    return GestureDetector(
      onTap: () => _selectCompetencyButton(title),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectedCompetencyType == title
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedCompetencyType == title
                ? const Color(0xFF1E3A8A)
                : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selectedCompetencyType == title
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
                Text(
                  'R$value',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: selectedCompetencyType == title
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            if (selectedCompetencyType == title) ...[
              const SizedBox(height: 8),
              Text(
                buttonDescriptions[title]!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceButton(String title, String value) {
    return GestureDetector(
      onTap: () => _selectDistanceButton(title),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectedDistanceType == title
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedDistanceType == title
                ? const Color(0xFF1E3A8A)
                : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: selectedDistanceType == title
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
            Text(
              'R$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selectedDistanceType == title
                    ? Colors.white
                    : Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                isForMyself = true;
                selectedDistanceType = null;
                _calculateTotalPrice();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isForMyself
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isForMyself
                      ? const Color(0xFF1E3A8A)
                      : Colors.white.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Public Transport',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isForMyself
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                isForMyself = false;
                selectedDistanceType = null;
                _calculateTotalPrice();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: !isForMyself
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !isForMyself
                      ? const Color(0xFF1E3A8A)
                      : Colors.white.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Own Vehicle',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: !isForMyself
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableConsultants() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _availableConsultantCount > 0
            ? Colors.white.withOpacity(0.2)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _availableConsultantCount > 0
              ? Colors.white.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Available Consultants',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_availableConsultantCount',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_industryType != null)
            Text(
              'Industry: $_industryType',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          if (_availableConsultantCount == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No consultants available for this industry',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade300,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalPriceDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Total Price',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'R${totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'VAT (15%): R${vatAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    bool isEnabled =
        _availableConsultantCount > 0 &&
        selectedCompetencyType != null &&
        selectedDistanceType != null &&
        _industryType != null &&
        _industryType!.isNotEmpty;

    return Column(
      children: [
        GestureDetector(
          onTap: isEnabled ? _storeDataAndNavigate : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: isEnabled
                  ? const LinearGradient(
                      colors: [Colors.white, Color(0xFFF0F0F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isEnabled ? null : Colors.grey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              'Accept',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isEnabled
                    ? const Color(0xFF1E3A8A)
                    : Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        ),
        if (!isEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _getSubmitButtonMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade300, fontSize: 14),
            ),
          ),
      ],
    );
  }

  String _getSubmitButtonMessage() {
    List<String> messages = [];
    if (_industryType == null || _industryType!.isEmpty) {
      messages.add('Industry type is missing');
    }
    if (_availableConsultantCount == 0) {
      messages.add('No consultants available for this industry');
    }
    if (selectedCompetencyType == null) {
      messages.add('Please select a competency level');
    }
    if (selectedDistanceType == null) {
      messages.add('Please select a distance range');
    }
    return messages.join('\n');
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
                        'Loading...',
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
                                  'Consultant Competency',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DashboardPage(),
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.arrow_back,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 24,
                                    ),
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

                      // Competency Selection
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: 'Level of Competency',
                            icon: Icons.person,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select the desired expertise level for your consultant',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildSkillLevelButton(
                                  'Level 1 - Basic Knowledge',
                                  '500.00',
                                ),
                                _buildSkillLevelButton(
                                  'Level 2 - Skilled In Industry',
                                  '937.50',
                                ),
                                _buildSkillLevelButton(
                                  'Level 3 - High Level Of Expertise',
                                  '2187.50',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Travel Requirements
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: 'Travel Requirements',
                            icon: Icons.directions_car,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select the transportation method and distance range',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTransportToggle(),
                                const SizedBox(height: 16),
                                if (isForMyself) ...[
                                  _buildDistanceButton(
                                    'Local - Within a 50km Radius',
                                    '187.50',
                                  ),
                                  _buildDistanceButton(
                                    'Regional - Within a 300km Radius',
                                    '475.00',
                                  ),
                                  _buildDistanceButton(
                                    'National - Within a 1500km Radius',
                                    '6250.50',
                                  ),
                                ] else ...[
                                  _buildDistanceButton(
                                    'Local - Within a 50km Radius',
                                    '437.50',
                                  ),
                                  _buildDistanceButton(
                                    'Regional - Within a 300km Radius',
                                    '1450.00',
                                  ),
                                  _buildDistanceButton(
                                    'Provincial - Within a 500km Radius',
                                    '1950.00',
                                  ),
                                  _buildDistanceButton(
                                    'Interprovincial - Within a 1000km Radius',
                                    '3106.25',
                                  ),
                                  _buildDistanceButton(
                                    'National - Within a 1500km Radius',
                                    '10937.50',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Available Consultants
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildAvailableConsultants(),
                        ),
                      ),

                      // Total Price
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildTotalPriceDisplay(),
                        ),
                      ),

                      // Submit Button
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildSubmitButton(),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
*/
