import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/theme.dart'; // Assuming theme.dart contains appGradient

class ChatScreen extends StatefulWidget {
  final String initialMessage;

  const ChatScreen({super.key, required this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  TextEditingController _userInput = TextEditingController();
  ScrollController _scrollController = ScrollController();

  // Replace with your actual API key
  static const apiKey = "AIzaSyDeZ9eYEBwwYCQLV82X_kuBIMhDrcLcSm0";

  late final GenerativeModel model;
  late final ChatSession chat;

  final List<Message> _messages = [];
  bool _isLoading = false;

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Predefined knowledge base for Dots
  final Map<String, String> dotsKnowledgeBase = {
    'what is dots': '''
Dots is a revolutionary platform that connects businesses with verified consultants for remote consultations, eliminating the need for expensive business travel. We provide expert consulting services across various industries through secure video calls and digital collaboration tools.
    ''',

    'business travel costs': '''
Dots helps reduce business travel costs by up to 80% by providing remote consulting services. Instead of flying consultants to your location or traveling to meet them, you can access the same expertise through our secure platform from anywhere in the world.
    ''',

    'industries consultants': '''
You can find consultants on Dots across multiple industries including:
- Technology & Software Development
- Finance & Banking
- Healthcare & Medical
- Marketing & Digital Strategy
- Legal & Compliance
- Manufacturing & Operations
- Human Resources
- Real Estate
- Education & Training
And many more specialized fields.
    ''',

    'sign up': '''
To sign up for Dots:
1. Download the Dots app from the App Store or Google Play
2. Click "Create Account" on the welcome screen
3. Enter your email address and create a secure password
4. Verify your email address
5. Complete your profile with business information
6. Start browsing available consultants or submit a consultation request
    ''',

    'submit request': '''
To submit a request for a consultant:
1. Log into your Dots account
2. Click "New Consultation Request"
3. Select your industry and consultation type
4. Describe your specific needs and requirements
5. Set your preferred timeline and budget
6. Submit the request
7. Our matching algorithm will connect you with suitable consultants within 24 hours
    ''',

    'get matched': '''
Our AI-powered matching system connects you with consultants based on:
- Your industry and specific needs
- Consultant expertise and track record
- Availability and timezone compatibility
- Budget requirements
- Past client reviews and ratings
You'll receive consultant profiles within 24 hours and can choose who to work with.
    ''',

    'verified consultants': '''
Yes, all consultants on Dots are thoroughly verified through:
- Professional credential verification
- Background checks
- Portfolio and work history review
- Client reference checks
- Ongoing performance monitoring
- Regular re-certification processes
We maintain the highest standards to ensure you work with qualified professionals.
    ''',

    'receive reports': '''
You'll receive consultation reports through:
- Real-time updates during sessions
- Detailed written reports within 48 hours
- Downloadable documents and presentations
- Video recordings of sessions (if requested)
- Follow-up recommendations and action items
- Access to all materials through your Dots dashboard
    ''',

    'secure payments': '''
Dots uses enterprise-grade security for all payments:
- 256-bit SSL encryption
- PCI DSS compliance
- Escrow payment system
- Multiple payment methods (credit cards, wire transfers, digital wallets)
- Fraud detection and prevention
- Money-back guarantee for unsatisfactory services
- Transparent pricing with no hidden fees
    ''',

    'login issues': '''
If you can't log in to your account:
1. Check if your email and password are correct
2. Try resetting your password using "Forgot Password"
3. Clear your browser cache or app cache
4. Check if your account is temporarily locked
5. Ensure you have a stable internet connection
6. Try logging in from a different device
If issues persist, contact our support team at support@dots.com
    ''',

    'customer support': '''
You can contact Dots customer support through:
- Email: support@dots.com
- Phone: +1-800-DOTS-HELP (24/7)
- Live chat in the app (9 AM - 9 PM EST)
- Help center: help.dots.com
- Submit a ticket through your dashboard
Our average response time is under 2 hours during business hours.
    ''',

    'download app': '''
You can download the Dots app from:
- iOS: Search "Dots Consulting" on the App Store
- Android: Search "Dots Consulting" on Google Play Store
- Web: Access our web platform at app.dots.com
- Direct links are available on our website: www.dots.com/download
The app is free to download with no subscription fees.
    ''',
  };

  @override
  void initState() {
    super.initState();
    _initializeAI();
    _initAnimations();
    _createBannerAd();

    if (widget.initialMessage.isNotEmpty) {
      _userInput.text = widget.initialMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sendMessage();
      });
    }
  }

  void _initializeAI() {
    model = GenerativeModel(
      model: 'gemini-1.5-flash', // Using the latest model
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
    );

    // Initialize chat with system instructions
    chat = model.startChat(
      history: [
        Content.text('''
You are a helpful customer support assistant for Dots, a platform that connects businesses with verified consultants for remote consultations. 

Key information about Dots:
- Reduces business travel costs by up to 80%
- Provides verified consultants across multiple industries
- Offers secure remote consultation services
- Has a mobile app and web platform

Always be helpful, professional, and provide accurate information about Dots services. If you don't know something specific, direct users to contact support at support@dots.com.
      '''),
      ],
    );
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

    _animationController.forward();
  }

  void _createBannerAd() {
    // Use test ad unit ID for development
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5630199363228429/1558075005', // Test ad unit ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
          print('Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
        },
        onAdOpened: (ad) => print('Banner ad opened'),
        onAdClosed: (ad) => print('Banner ad closed'),
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _userInput.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _findBestMatch(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    // Direct keyword matching
    for (String key in dotsKnowledgeBase.keys) {
      if (lowerMessage.contains(key)) {
        return dotsKnowledgeBase[key]!;
      }
    }

    // Check for common variations
    if (lowerMessage.contains('cost') ||
        lowerMessage.contains('save') ||
        lowerMessage.contains('money')) {
      return dotsKnowledgeBase['business travel costs']!;
    }

    if (lowerMessage.contains('industry') ||
        lowerMessage.contains('field') ||
        lowerMessage.contains('sector')) {
      return dotsKnowledgeBase['industries consultants']!;
    }

    if (lowerMessage.contains('register') ||
        lowerMessage.contains('join') ||
        lowerMessage.contains('account')) {
      return dotsKnowledgeBase['sign up']!;
    }

    if (lowerMessage.contains('payment') ||
        lowerMessage.contains('pay') ||
        lowerMessage.contains('billing')) {
      return dotsKnowledgeBase['secure payments']!;
    }

    if (lowerMessage.contains('support') ||
        lowerMessage.contains('help') ||
        lowerMessage.contains('contact')) {
      return dotsKnowledgeBase['customer support']!;
    }

    return '';
  }

  Future<void> sendMessage() async {
    final message = _userInput.text.trim();

    if (message.isEmpty) return;

    setState(() {
      _messages.add(
        Message(isUser: true, message: message, date: DateTime.now()),
      );
      _userInput.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      String response;

      // First, try to find a match in our knowledge base
      String knowledgeResponse = _findBestMatch(message);

      if (knowledgeResponse.isNotEmpty) {
        response = knowledgeResponse;
      } else {
        // If no direct match, use AI with context
        final prompt =
            '''
        User question: "$message"
        
        Please provide a helpful response about Dots consulting platform. If this question is not related to Dots, politely redirect the user to ask about Dots services and mention they can contact support@dots.com for specific inquiries.
        ''';

        final result = await chat.sendMessage(Content.text(prompt));
        response =
            result.text ??
            "I'm sorry, I couldn't generate a response. Please try again or contact our support team at support@dots.com.";
      }

      if (mounted) {
        setState(() {
          _messages.add(
            Message(isUser: false, message: response, date: DateTime.now()),
          );
          _isLoading = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
      print('Error generating response: $e');
      if (mounted) {
        setState(() {
          _messages.add(
            Message(
              isUser: false,
              message:
                  "I'm experiencing some technical difficulties. Please try again later or contact our support team at support@dots.com for immediate assistance.",
              date: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _title() {
    return const Text(
      'Support',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _appBarImage() {
    return Container(
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
            const Icon(Icons.error_outline, color: Color(0xFF1E3A8A), size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        _appBarImage(),
                        const SizedBox(width: 16),
                        _title(),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),

              // Chat Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) {
                      return SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Typing...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final message = _messages[index];
                    return SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Messages(
                          isUser: message.isUser,
                          message: message.message,
                          date: DateFormat('HH:mm').format(message.date),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Banner Ad
              if (_isAdLoaded && _bannerAd != null)
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        ),
                      ),
                    ),
                  ),
                ),

              // Input Field
              Padding(
                padding: const EdgeInsets.all(16),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: TextFormField(
                              controller: _userInput,
                              style: const TextStyle(color: Colors.white),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onFieldSubmitted: (_) => sendMessage(),
                              decoration: InputDecoration(
                                hintText: 'Ask me about Dots...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoading ? null : sendMessage,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isLoading
                                      ? [Colors.grey, Colors.grey.shade300]
                                      : [Colors.white, const Color(0xFFF0F0F0)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.send,
                                color: _isLoading
                                    ? Colors.grey.shade600
                                    : const Color(0xFF1E3A8A),
                                size: 24,
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
          ),
        ),
      ),
    );
  }
}

class Message {
  final bool isUser;
  final String message;
  final DateTime date;

  Message({required this.isUser, required this.message, required this.date});
}

class Messages extends StatelessWidget {
  final bool isUser;
  final String message;
  final String date;

  const Messages({
    super.key,
    required this.isUser,
    required this.message,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: isUser ? 32 : 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUser
            ? const Color(0xFF1E3A8A)
            : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
          topRight: const Radius.circular(16),
          bottomRight: isUser ? Radius.zero : const Radius.circular(16),
        ),
        border: Border.all(
          color: isUser
              ? const Color(0xFF1E3A8A).withOpacity(0.5)
              : Colors.white.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            message,
            style: TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
