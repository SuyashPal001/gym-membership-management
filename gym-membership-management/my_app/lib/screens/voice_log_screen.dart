import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

enum VoiceSessionState { idle, active, processing, summary }

class VoiceLogScreen extends StatefulWidget {
  const VoiceLogScreen({Key? key}) : super(key: key);

  @override
  State<VoiceLogScreen> createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends State<VoiceLogScreen>
    with TickerProviderStateMixin {

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _rippleController;

  VoiceSessionState _state = VoiceSessionState.idle;
  String? _sessionId;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _chatMessages = [];

  String _liveText = '';
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isSending = false;
  bool _isHindi = false;
  String? _pendingPrompt;

  int _loggedCount = 0;

  int _tickerIndex = 0;
  late Timer? _tickerTimer;
  final List<String> _prompts = [
    "KISI KI ATTENDANCE YA PAYMENT MARK KARNI HAI?",
    "SHOW ME TODAY'S TOTAL COLLECTION & STATUS",
    "AAJ KI SAARI PAYMENTS DIKHAO",
    "MARK SOMEONE'S ATTENDANCE AND PAYMENT",
    "KISI KI LAST MONTH KI PAYMENT CHECK KARO",
    "ASK ABOUT SOMEONE'S PAYMENT LAST MONTH",
  ];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _rippleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();

    // Cinematic Rotation Ticker
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() { _tickerIndex = (_tickerIndex + 1) % _prompts.length; });
      }
    });
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(_isHindi ? 'hi-IN' : 'en-IN');
    await _tts.setSpeechRate(0.52);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    setState(() { _isSpeaking = true; _isListening = false; });
    bool spokenByJustAudio = false;
    try {
      final audioBase64 = await ApiService.textToSpeech(text, isHindi: _isHindi);
      if (audioBase64.isNotEmpty) {
        final audioBytes = base64Decode(audioBase64);
        final audioSource = _BytesAudioSource(audioBytes);
        await _audioPlayer.setAudioSource(audioSource);
        await _audioPlayer.play();
        await _audioPlayer.processingStateStream.firstWhere(
          (state) => state == ProcessingState.completed,
        );
        spokenByJustAudio = true;
      }
    } catch (_) {
      // just_audio / backend TTS failed — fall through to device TTS
    }

    if (!spokenByJustAudio) {
      try {
        final completer = Completer<void>();
        _tts.setCompletionHandler(() {
          if (!completer.isCompleted) completer.complete();
        });
        await _tts.speak(text);
        await completer.future.timeout(
          Duration(seconds: text.length ~/ 8 + 5),
          onTimeout: () {},
        );
      } catch (_) {
        // device TTS also failed — session continues silently
      }
    }

    setState(() { _isSpeaking = false; });
    if (_state == VoiceSessionState.active) {
      _startListening();
    }
  }

  Future<void> _startSession() async {
    try {
      final bool available = await _stt.initialize();
      if (!available) {
        _showError('Microphone not available');
        return;
      }

      final result = await ApiService.startVoiceSession();

      setState(() {
        _sessionId = result['session_id'];
        _state = VoiceSessionState.active;
        _chatMessages = [];
        _history = [];
      });

      final openingMessage = result['opening_message'] as String?;
      if (openingMessage != null && openingMessage.isNotEmpty) {
        _addAiMessage(openingMessage);
        await _speak(openingMessage);
      }

      if (_pendingPrompt != null) {
        final prompt = _pendingPrompt!;
        _pendingPrompt = null;
        _addOwnerMessage(prompt);
        await _sendMessage(prompt);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _startListening() async {
    if (_isListening || _isSpeaking) return;
    setState(() { _isListening = true; _liveText = ''; });

    await _stt.listen(
      onResult: (result) {
        setState(() { _liveText = result.recognizedWords; });
        if (result.finalResult && _liveText.isNotEmpty) {
          _stopListeningAndSend();
        }
      },
      localeId: _isHindi ? 'hi_IN' : 'en_IN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      cancelOnError: false,
    );
  }

  Future<void> _stopListeningAndSend() async {
    if (_isSending) return;
    _isSending = true;
    await _stt.stop();
    setState(() { _isListening = false; });

    final text = _liveText.trim();
    if (text.isEmpty) { _isSending = false; return; }

    _addOwnerMessage(text);
    setState(() { _liveText = ''; });
    await _sendMessage(text);
    _isSending = false;
  }

  Future<void> _sendMessage(String text) async {
    try {
      final response = await ApiService.sendVoiceMessage(
        _sessionId!, text, _history, isHindi: _isHindi);

      final reply = response['reply'] as String? ?? '';
      final complete = response['session_complete'] as bool? ?? false;

      _history.add({'role': 'user', 'text': text});
      _history.add({'role': 'ai', 'text': reply});

      _addAiMessage(reply);

      if (complete) {
        await _speak(reply);
        await _endSession();
      } else {
        await _speak(reply);
      }
    } catch (e) {
      _addAiMessage("Sorry, something went wrong. Please try again.");
      await _speak("Sorry, kuch problem ho gayi. Dobara try karo.");
    }
  }

  Future<void> _endSession() async {
    await _stt.stop();
    await _tts.stop();
    setState(() { _state = VoiceSessionState.processing; });
    try {
      final result = await ApiService.endVoiceSession(_sessionId!);
      setState(() {
        _loggedCount = result['total_logged'] ?? 0;
        _state = VoiceSessionState.summary;
      });
    } catch (e) {
      _showError(e.toString());
      setState(() { _state = VoiceSessionState.active; });
    }
  }

  void _addAiMessage(String text) {
    setState(() { _chatMessages.add({'role': 'ai', 'text': text}); });
    _scrollToBottom();
  }

  void _addOwnerMessage(String text) {
    setState(() { _chatMessages.add({'role': 'owner', 'text': text}); });
    _scrollToBottom();
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cardBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _rotationController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    _audioPlayer.dispose();
    _stt.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'VOICE ASSISTANT',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ),
      body: Stack(
        children: [
          // Global Ambient Glow
          Positioned(
            top: -150,
            left: 0,
            right: 0,
            height: 600,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.1),
                    AppColors.background.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _buildStateContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent() {
    switch (_state) {
      case VoiceSessionState.idle:
        return _buildIdle();
      case VoiceSessionState.active:
        return _buildActive();
      case VoiceSessionState.processing:
        return _buildProcessing();
      case VoiceSessionState.summary:
        return _buildSummary();
    }
  }

  // ── Idle ──────────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 3),
            _buildAmbientCore(),
            const Spacer(flex: 2),
            _buildPromptTicker(),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientCore() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.vibrate();
            _startSession();
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_rotationController, _pulseController, _rippleController]),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Layer 1: Ambient Atmosphere (Rotating)
                  RotationTransition(
                    turns: _rotationController,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          center: Alignment.center,
                          colors: [
                            AppColors.primaryBlue.withOpacity(0.0),
                            AppColors.primaryBlue.withOpacity(0.18),
                            AppColors.primaryBlue.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Layer 2: Breathing Neural Aura
                  Container(
                    width: 150 + (25 * _pulseController.value),
                    height: 150 + (25 * _pulseController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryBlue.withOpacity(0.25 * (1 - _pulseController.value)),
                          AppColors.primaryBlue.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  // Layer 3: The Interactive Core
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cardBackground,
                      border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.15),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.mic_rounded,
                        size: 48,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  // Layer 4: Kinetic Pulse Ring (Intermittent)
                  Opacity(
                    opacity: (1 - _rippleController.value).clamp(0.0, 1.0),
                    child: Container(
                      width: 120 + (160 * _rippleController.value),
                      height: 120 + (160 * _rippleController.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 48),
        const Text(
          'FLEXY',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 10.0,
          ),
        ),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.white.withOpacity(0.4), Colors.white, Colors.white.withOpacity(0.4)],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: Text(
            'INTELLIGENT STUDIO CONTROL',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w500,
              letterSpacing: 4.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptTicker() {
    return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 10, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  "TRY SAYING",
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            height: 64,
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (Widget child, Animation<double> animation) {
                final bool isEntering = child.key == ValueKey<int>(_tickerIndex);
                final offsetTween = isEntering 
                    ? Tween<Offset>(begin: const Offset(0.0, 1.4), end: Offset.zero)
                    : Tween<Offset>(begin: const Offset(0.0, -1.4), end: Offset.zero);
                    
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetTween.animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
                    ),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                key: ValueKey<int>(_tickerIndex),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _pendingPrompt = _prompts[_tickerIndex]);
                  _startSession();
                },
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white.withOpacity(0.3), Colors.white, Colors.white.withOpacity(0.3)],
                      stops: const [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: Text(
                      _prompts[_tickerIndex],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 30,
            height: 1.5,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      );
  }

  // ── Active ────────────────────────────────────────────────────────────────

  Widget _buildActive() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          _isSpeaking ? "FLEXY IS SPEAKING" : (_isListening ? "FLEXY IS LISTENING" : "READY"),
          style: TextStyle(color: AppColors.primaryBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 3.0),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              final isAi = msg['role'] == 'ai';
              return _buildPremiumBubble(msg['text'] as String, isAi);
            },
          ),
        ),
        _buildMinimalistControls(),
      ],
    );
  }

  Widget _buildPremiumBubble(String text, bool isAi) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (isAi)
            Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 6),
              child: Text(
                "FLEXY",
                style: GoogleFonts.outfit(
                  color: AppColors.primaryBlue.withOpacity(0.6),
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAi) ...[
                // THE NEURAL ORB AVATAR
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryBlue.withOpacity(0.2),
                        AppColors.background,
                      ],
                    ),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.bolt_rounded, size: 14, color: AppColors.primaryBlue),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isAi ? AppColors.cardBackground.withOpacity(0.6) : AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(24).copyWith(
                      topLeft: isAi ? const Radius.circular(4) : null,
                      topRight: !isAi ? const Radius.circular(4) : null,
                    ),
                    border: isAi ? Border.all(color: Colors.white.withOpacity(0.04), width: 1) : null,
                    gradient: isAi ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.0),
                      ],
                    ) : null,
                  ),
                  child: Text(
                    text,
                    style: GoogleFonts.outfit(
                      color: isAi ? Colors.white.withOpacity(0.95) : Colors.black,
                      fontSize: 15,
                      fontWeight: isAi ? FontWeight.w400 : FontWeight.w600,
                      height: 1.45,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
              if (!isAi) const SizedBox(width: 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistControls() {
    return Container(
      padding: EdgeInsets.fromLTRB(32, 20, 32, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isListening && _liveText.isNotEmpty) ...[
             Text(
              "\"$_liveText\"",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // KINETIC LANGUAGE TOGGLE
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isHindi = !_isHindi);
                  _initTts();
                },
                child: Container(
                  width: 90,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                  ),
                  child: Stack(
                    children: [
                      // Sliding Highlight
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        alignment: _isHindi ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 44,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3), width: 1),
                          ),
                        ),
                      ),
                      // Labels
                      Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                'EN',
                                style: GoogleFonts.outfit(
                                  color: !_isHindi ? AppColors.primaryBlue : Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'HI',
                                style: GoogleFonts.outfit(
                                  color: _isHindi ? AppColors.primaryBlue : Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _isListening ? _stopListeningAndSend : _startListening,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isListening)
                      const SizedBox(
                        width: 76,
                        height: 76,
                        child: CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 2),
                      ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.white : AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24 + 14 + 14 + 11 + 3.0), // balance spacing
            ],
          ),
        ],
      ),
    );
  }

  // ── Processing ────────────────────────────────────────────────────────────

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loader.json',
            width: 150,
            height: 150,
            delegates: LottieDelegates(
              values: [
                ValueDelegate.colorFilter(
                  ['**'],
                  value: ColorFilter.mode(AppColors.primaryBlue, BlendMode.modulate),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'SYNCHRONIZING...',
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "SYNC COMPLETE",
            style: TextStyle(color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4.0),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(40),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  _loggedCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 84, fontWeight: FontWeight.w800, height: 1),
                ),
                Text(
                  _loggedCount == 1 ? "ENTRY LOGGED" : "ENTRIES LOGGED",
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("FINISH SESSION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
            ),
          ),
        ],
      ),
    );
  }

}

class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  _BytesAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: e - s,
      offset: s,
      contentType: 'audio/mpeg',
      stream: Stream.value(_bytes.sublist(s, e)),
    );
  }
}
