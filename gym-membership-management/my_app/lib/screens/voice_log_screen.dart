import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

enum VoiceSessionState { idle, active, processing, summary }

class VoiceLogScreen extends StatefulWidget {
  const VoiceLogScreen({Key? key}) : super(key: key);

  @override
  State<VoiceLogScreen> createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends State<VoiceLogScreen> 
    with SingleTickerProviderStateMixin {
  
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;

  VoiceSessionState _state = VoiceSessionState.idle;
  String? _sessionId;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _chatMessages = [];
  
  String _liveText = '';
  bool _isListening = false;
  bool _isSpeaking = false;
  
  int _loggedCount = 0;
  int _skippedCount = 0;
  List<String> _skippedReasons = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _initTts();
  }

  void _initTts() {
    // GCP TTS used instead — no device TTS init needed
  }

  Future<void> _speak(String text) async {
    setState(() { _isSpeaking = true; _isListening = false; });
    try {
      final audioBase64 = await ApiService.textToSpeech(text);
      if (audioBase64.isEmpty) {
        setState(() { _isSpeaking = false; });
        _startListening();
        return;
      }
      
      final audioBytes = base64Decode(audioBase64);
      final audioSource = AudioSource.uri(
        Uri.dataFromBytes(audioBytes, mimeType: 'audio/mp3')
      );
      
      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
      await _audioPlayer.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed
      );
      
    } catch (e) {
      print('[TTS ERROR] $e');
    } finally {
      setState(() { _isSpeaking = false; });
      if (_state == VoiceSessionState.active) {
        _startListening();
      }
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
        _members = List<Map<String, dynamic>>.from(result['members'] ?? []);
        _state = VoiceSessionState.active;
        _chatMessages = [];
        _history = [];
      });

      final openingMessage = result['opening_message'] as String?;
      if (openingMessage != null && openingMessage.isNotEmpty) {
        _addAiMessage(openingMessage);
        await _speak(openingMessage);
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
      localeId: 'en_IN',
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _stopListeningAndSend() async {
    await _stt.stop();
    setState(() { _isListening = false; });
    
    final text = _liveText.trim();
    if (text.isEmpty) return;

    _addOwnerMessage(text);
    setState(() { _liveText = ''; });
    await _sendMessage(text);
  }

  Future<void> _sendMessage(String text) async {
    try {
      final response = await ApiService.sendVoiceMessage(
        _sessionId!, text, _history);

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
        _skippedCount = result['total_skipped'] ?? 0;
        _state = VoiceSessionState.summary;
      });
    } catch (e) {
      _showError(e.toString());
      setState(() { _state = VoiceSessionState.active; });
    }
  }

  void _addAiMessage(String text) {
    setState(() {
      _chatMessages.add({'role': 'ai', 'text': text});
    });
    _scrollToBottom();
  }

  void _addOwnerMessage(String text) {
    setState(() {
      _chatMessages.add({'role': 'owner', 'text': text});
    });
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
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stt.stop();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _state == VoiceSessionState.active ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox(),
        title: Text('Gym Assistant',
          style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _endSession,
            child: Text('End Session',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ) : null,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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

  Widget _buildIdle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 160 + (_pulseController.value * 40),
                height: 160 + (_pulseController.value * 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.1 + (_pulseController.value * 0.15)),
                ),
                child: Center(
                  child: GestureDetector(
                    onTap: _startSession,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                      child: const Icon(Icons.mic, size: 56, color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Start Voice Log',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            )),
          const SizedBox(height: 12),
          Text('Tap to begin logging today\'s session',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActive() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              final isAi = msg['role'] == 'ai';
              return Align(
                alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: 12,
                    left: isAi ? 0 : 48,
                    right: isAi ? 48 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isAi
                      ? AppColors.accent.withOpacity(0.12)
                      : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      topLeft: isAi ? Radius.zero : const Radius.circular(16),
                      topRight: isAi ? const Radius.circular(16) : Radius.zero,
                    ),
                    border: Border.all(
                      color: isAi
                        ? AppColors.accent.withOpacity(0.3)
                        : AppColors.border,
                    ),
                  ),
                  child: Text(msg['text'] as String,
                    style: TextStyle(
                      color: AppColors.primaryText, fontSize: 15, height: 1.4)),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isListening
                    ? (_liveText.isEmpty ? 'Listening...' : _liveText)
                    : (_isSpeaking ? 'AI is speaking...' : 'Tap mic to speak'),
                  style: TextStyle(
                    color: _isListening ? AppColors.primaryText : AppColors.secondaryText,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isListening ? _stopListeningAndSend : _startListening,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening
                          ? AppColors.accent.withOpacity(0.7 + _pulseController.value * 0.3)
                          : AppColors.accent.withOpacity(0.4),
                      ),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 26,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 24),
          Text('Logging your session...',
            style: TextStyle(color: AppColors.primaryText, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('✅ $_loggedCount ${_loggedCount == 1 ? "entry" : "entries"} logged',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            )),
          if (_skippedCount > 0) ...[
            const SizedBox(height: 24),
            Text('$_skippedCount skipped',
              style: TextStyle(color: Colors.amber, fontSize: 16)),
            const SizedBox(height: 12),
            ..._skippedReasons.map((reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• $reason',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
            )),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                )),
            ),
          ),
        ],
      ),
    );
  }
}
