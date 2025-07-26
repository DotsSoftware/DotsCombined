import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'consultant_dashboard.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient

class TermsPage extends StatefulWidget {
  const TermsPage({Key? key}) : super(key: key);

  @override
  _TermsPageState createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> with TickerProviderStateMixin {
  String? _errorMessage;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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
      end: Offset.zero,
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

  Widget _termsAndConditions() {
    return Text(
      '''
Terms and Conditions

1. Introduction
Welcome to Dots, an innovative platform designed to connect business clients with qualified consultants. By using our app, you agree to these Terms and Conditions. Please read them carefully.

2. Definitions
- **App:** Refers to the Dots mobile application.
- **User:** Refers to anyone who uses the app, including both clients and consultants.
- **Client:** A user who seeks services through the app.
- **Consultant:** A user who provides services through the app.
- **Services:** The consulting services provided by consultants to clients.

3. Acceptance of Terms
By downloading, accessing, or using the Dots app, you agree to be bound by these Terms and Conditions and our Privacy Policy. If you do not agree with these terms, please do not use the app.

4. Registration
- Users must register an account to use the services provided by the app.
- Consultants must provide accurate and complete information during the registration process and keep this information up to date.

5. Use of the App
- Users agree to use the app in accordance with all applicable laws and regulations.
- Users must not misuse the app or its services, including but not limited to interfering with the normal operation of the app or attempting to access it using a method other than the interface provided.

6. Consultant Responsibilities
- Consultants are responsible for providing accurate information about their qualifications and expertise.
- Consultants must ensure that they have the necessary skills and qualifications to provide the services they offer.
- Consultants must comply with all applicable laws and professional standards in the provision of their services.

7. Client Responsibilities
- Clients are responsible for providing accurate and complete information when requesting services.
- Clients must pay for the services provided by consultants in accordance with the agreed terms.

8. Payment and Fees
- Payment for services will be handled through the app’s payment system.
- Consultants will receive payment for their services minus any applicable service fees.

9. Cancellations and Refunds
- Cancellations and refunds will be handled in accordance with the app’s cancellation and refund policy, which is available on the app.

10. Intellectual Property
- All content and materials on the app, including but not limited to text, graphics, logos, and software, are the property of Dots or its licensors and are protected by intellectual property laws.
- Users may not use any content from the app without prior written permission from Dots.

11. Privacy
- Our Privacy Policy outlines how we collect, use, and protect your information. By using the app, you agree to the terms of our Privacy Policy.

12. Disclaimers
- The app and services are provided on an "as is" and "as available" basis. We do not warrant that the app will be uninterrupted or error-free.
- We do not endorse or guarantee the qualifications, expertise, or services of any consultant.

13. Limitation of Liability
- To the fullest extent permitted by law, Dots shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses resulting from your use of the app or services.

14. Changes to Terms
- We reserve the right to modify these Terms and Conditions at any time. Any changes will be effective immediately upon posting on the app. Your continued use of the app following the posting of changes constitutes your acceptance of such changes.

15. Governing Law
- These Terms and Conditions are governed by and construed in accordance with the laws of South Africa, without regard to its conflict of law principles.

16. Contact Us
- If you have any questions about these Terms and Conditions, please contact us at info@dotssa.co.za.
      ''',
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withOpacity(0.8),
        height: 1.5,
      ),
    );
  }

  Future<void> _acceptTerms() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await FirebaseFirestore.instance
            .collection('consultant_side')
            .doc(user.uid)
            .set(
          {
            'termsAccepted': true,
            'termsAcceptedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Terms accepted successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ConsultantDashboardPage()),
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Error accepting terms: $e';
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
                                'Boring, but Important',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Read and accept to continue',
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

                      // Terms and Conditions
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildModernCard(
                            title: 'Terms and Conditions',
                            icon: Icons.description_outlined,
                            child: _termsAndConditions(),
                          ),
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

                      // Accept Button
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            margin: const EdgeInsets.only(top: 16),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _acceptTerms,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
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
                                        Icons.check,
                                        color: Color(0xFF1E3A8A),
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Accept and Continue',
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
