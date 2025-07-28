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

  static const apiKey = "AIzaSyDrf4oquiy8pK4eCFlCPo__WTU-6UciK8Q";

  final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);

  final List<Message> _messages = [];

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    if (widget.initialMessage.isNotEmpty) {
      _userInput.text = widget.initialMessage;
      sendMessage();
      _createBannerAd();
    }
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
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5630199363228429/1139015448',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
          print('Ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: ${error.message}');
          ad.dispose();
        },
        onAdOpened: (ad) => print('Ad opened'),
        onAdClosed: (ad) => print('Ad closed'),
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

  Future<void> sendMessage() async {
    final message = _userInput.text;

    setState(() {
      _messages.add(
        Message(isUser: true, message: message, date: DateTime.now()),
      );
      _userInput.clear();
    });

    final chatHistory = [
      "What is Dots?",
      "How does Dots help in reducing business travel costs?",
      "In which industries can I find consultants on Dots?",
      "How do I sign up for Dots?",
      "How do I submit a request for a consultant?",
      "How do I get matched with a consultant?",
      "Are the consultants on Dots verified?",
      "How do I receive reports from the consultant?",
      "How secure are the payments made through Dots?",
      "I can't log in to my account. What should I do?",
      "How can I contact customer support?",
      "Where can I download the Dots app?",
    ];

    final relevantHistory = chatHistory
        .where(
          (element) => element.toLowerCase().contains(message.toLowerCase()),
        )
        .toList();

    final content = relevantHistory.isNotEmpty
        ? relevantHistory.map((e) => Content.text(e)).toList()
        : [
            Content.text(
              "I couldn't find any matching prompt. Please ask a relevant question.",
            ),
          ];

    final response = await model.generateContent(content);

    setState(() {
      _messages.add(
        Message(
          isUser: false,
          message: response.text ?? "",
          date: DateTime.now(),
        ),
      );
    });

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
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
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: _isAdLoaded && _bannerAd != null
                        ? SizedBox(
                            width: _bannerAd!.size.width.toDouble(),
                            height: _bannerAd!.size.height.toDouble(),
                            child: AdWidget(ad: _bannerAd!),
                          )
                        : SizedBox(
                            width: AdSize.banner.width.toDouble(),
                            height: AdSize.banner.height.toDouble(),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1E3A8A),
                                ),
                              ),
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
                              decoration: InputDecoration(
                                hintText: 'Enter Your Message',
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
                            onTap: sendMessage,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.white, Color(0xFFF0F0F0)],
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
                              child: const Icon(
                                Icons.send,
                                color: Color(0xFF1E3A8A),
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
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: isUser ? Colors.white : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              color: isUser
                  ? Colors.white.withOpacity(0.7)
                  : Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
