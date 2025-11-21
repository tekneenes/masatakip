import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // YENİ
import 'package:url_launcher/url_launcher.dart'; // YENİ
import '../services/table_ai_service.dart';

// ARTIK SABİT API KEY KULLANMIYORUZ
// const String GEMINI_API_KEY = "AIzaSyCFZ3Vm4GY9F8lcfYkfb1JUJyFroWHFVeU";

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  final TableAIService _aiService = TableAIService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Content> _chatHistory = [];
  final List<ChatMessage> _displayMessages = [];

  bool _isLoading = false;
  String _thinkingPhase = '';
  late AnimationController _thinkingAnimController;
  late Animation<double> _thinkingAnimation;

  late FlutterTts _flutterTts;
  bool _isTtsInitialized = false;
  bool _isAutoPlayEnabled = false;

  // YENİ: API Anahtarı yönetimi
  String? _geminiApiKey;
  bool _isApiKeyChecking = true; // Başlangıçta anahtarı kontrol et
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initTts();

    _thinkingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _thinkingAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _thinkingAnimController, curve: Curves.easeInOut),
    );

    // YENİ: API anahtarını yükle ve servisi başlat
    _loadApiKeyAndInit();

    // Karşılama mesajı
    _displayMessages.add(ChatMessage(
      role: 'assistant',
      text:
          'Merhaba! 👋 Ben Table Intelligence. Size bugünkü ciro, ödenmemiş veresiyeler, masa durumları ve daha fazlası hakkında yardımcı olabilirim.',
      timestamp: DateTime.now(),
    ));
  }

  // YENİ: Kayıtlı API anahtarını yükler
  Future<void> _loadApiKeyAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key');

    if (apiKey != null && apiKey.isNotEmpty) {
      _initializeServices(apiKey);
    } else {
      // Anahtar yoksa, ilk frame'den sonra diyaloğu göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showApiKeyDialog();
      });
    }
    setState(() => _isApiKeyChecking = false);
  }

  // YENİ: Gemini servisini API anahtarıyla başlatır
  void _initializeServices(String apiKey) {
    try {
      Gemini.init(apiKey: apiKey);
      setState(() => _geminiApiKey = apiKey);
      debugPrint("Gemini servisi başarıyla başlatıldı.");
    } catch (e) {
      debugPrint("Gemini başlatılırken hata: $e");
      setState(() => _geminiApiKey = null);
      // Hata durumunda tekrar diyaloğu göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showApiKeyDialog(
            error:
                "API Anahtarı geçersiz veya başlatılamadı. Lütfen kontrol edin.");
      });
    }
  }

  // YENİ: API Anahtarı isteme diyaloğu
  Future<void> _showApiKeyDialog({String? error}) async {
    _apiKeyController.text =
        _geminiApiKey ?? ''; // Varsa mevcut anahtarı göster

    showDialog(
      context: context,
      barrierDismissible: false, // Kapatılamaz
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.key_rounded, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Gemini API Anahtarı'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error != null) ...[
                      Text(
                        error,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'Lütfen devam etmek için Google Gemini API anahtarınızı girin.',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Anahtarı',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'API Anahtarı Nasıl Alınır?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLinkText(
                      context,
                      "1. Google AI Studio'ya gidin.",
                      'https://aistudio.google.com/app/apikey',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "2. 'Create API key' (API anahtarı oluştur) butonuna tıklayın.",
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "3. Oluşturulan anahtarı kopyalayıp yukarıdaki alana yapıştırın.",
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              actions: [
                if (_geminiApiKey != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(), // Kapat
                    child: const Text('İptal'),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () async {
                    final newKey = _apiKeyController.text.trim();
                    if (newKey.isEmpty) return;

                    // Anahtarı kaydet
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('gemini_api_key', newKey);

                    // Servisi yeni anahtarla başlat
                    _initializeServices(newKey);

                    if (mounted) {
                      Navigator.of(context).pop(); // Diyaloğu kapat
                    }
                  },
                  child: const Text(
                    'Kaydet ve Başlat',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // YENİ: Tıklanabilir link oluşturan yardımcı widget
  Widget _buildLinkText(BuildContext context, String text, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.blue.shade700,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  // YENİ: URL açmak için yardımcı fonksiyon
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Link açılamadı: $url');
    }
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    _flutterTts.awaitSpeakCompletion(true);
    _flutterTts.setSpeechRate(0.45);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    List<dynamic> voices;
    try {
      voices = await _flutterTts.getVoices;
    } catch (e) {
      debugPrint("Sesleri alırken hata oluştu: $e");
      voices = [];
    }

    final turkishVoices = voices
        .where((voice) =>
            voice['locale'] != null &&
            voice['locale'].toLowerCase().contains('tr'))
        .toList();

    Map<String, String>? selectedVoice;

    if (turkishVoices.isNotEmpty) {
      final networkVoice = turkishVoices.firstWhere(
        (voice) =>
            voice['name'] != null &&
            voice['name'].toLowerCase().contains('network'),
        orElse: () => null,
      );
      final highQualityVoice = turkishVoices.firstWhere(
        (voice) =>
            voice['name'] != null &&
            voice['name'].toLowerCase().contains('high'),
        orElse: () => null,
      );

      if (networkVoice != null) {
        selectedVoice = {
          "name": networkVoice['name'],
          "locale": networkVoice['locale']
        };
      } else if (highQualityVoice != null) {
        selectedVoice = {
          "name": highQualityVoice['name'],
          "locale": highQualityVoice['locale']
        };
      } else {
        selectedVoice = {
          "name": turkishVoices[0]['name'],
          "locale": turkishVoices[0]['locale']
        };
      }
    }

    if (selectedVoice != null) {
      await _flutterTts.setVoice(selectedVoice);
    } else {
      debugPrint("Özel Türkçe ses bulunamadı. Dil 'tr-TR' olarak ayarlanıyor.");
      await _flutterTts.setLanguage("tr-TR");
    }

    if (mounted) {
      setState(() => _isTtsInitialized = true);
    }
  }

  Future<void> _speak(String text) async {
    if (_isTtsInitialized && text.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    _thinkingAnimController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    _apiKeyController.dispose(); // YENİ
    _flutterTts.stop();
    super.dispose();
  }

  void _sendMessage() async {
    // YENİ: API Anahtarı kontrolü
    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      _showApiKeyDialog(
          error: "Lütfen mesaj göndermeden önce API anahtarınızı ayarlayın.");
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = ChatMessage(
      role: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _displayMessages.add(userMessage);
      _controller.clear();
      _isLoading = true;
      _thinkingPhase = 'Sorgunuz analiz ediliyor...';
    });

    _scrollToBottom();

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() => _thinkingPhase = 'Veritabanı sorgulanıyor...');
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _thinkingPhase = 'Yanıt oluşturuluyor...');

      final responseText =
          await _aiService.getGeminiResponseWithRAG(text, _chatHistory);

      final assistantMessage = ChatMessage(
        role: 'assistant',
        text: responseText,
        timestamp: DateTime.now(),
        isAnimating: true,
      );

      final geminiResponseContent =
          Content(role: 'model', parts: [Part.text(responseText)]);

      setState(() {
        _chatHistory.add(Content(role: 'user', parts: [Part.text(text)]));
        _chatHistory.add(geminiResponseContent);
        _displayMessages.add(assistantMessage);
        _isLoading = false;
        _thinkingPhase = '';
      });

      _scrollToBottom();

      if (_isAutoPlayEnabled && _isTtsInitialized) {
        _speak(responseText);
      }

      _animateMessageText(assistantMessage);
    } catch (e) {
      String errorMessage = e.toString();
      // YENİ: API anahtarı hatasını yakala
      if (e.toString().toLowerCase().contains('api key not valid')) {
        errorMessage =
            'API Anahtarınız geçersiz veya süresi dolmuş. Lütfen kontrol edin.';
        // Hatalı anahtarı temizle ve diyaloğu göster
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('gemini_api_key');
        setState(() => _geminiApiKey = null);
        _showApiKeyDialog(error: errorMessage);
      }

      setState(() {
        _displayMessages.add(ChatMessage(
          role: 'system',
          text: '❌ Bir hata oluştu: $errorMessage',
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
        _thinkingPhase = '';
      });
      _scrollToBottom();
    }
  }

  void _animateMessageText(ChatMessage message) async {
    final fullText = message.text;
    for (int i = 0; i <= fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 15));
      if (mounted) {
        setState(() {
          message.displayedText = fullText.substring(0, i);
        });
        if (i % 10 == 0) _scrollToBottom();
      }
    }
    setState(() {
      message.isAnimating = false;
      message.displayedText = fullText;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // YENİ: API anahtarı kontrol edilirken yükleme ekranı göster
    if (_isApiKeyChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 16),
              Text(
                'Ayarlar yükleniyor...',
                style: TextStyle(fontSize: 16, color: Colors.teal),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table Intelligence',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Masa Takip Sistemi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        toolbarHeight: 70,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // YENİ: API Anahtarı Ayarlama Butonu
          IconButton(
            icon: Icon(
              Icons.key_rounded,
              size: 24,
              color:
                  _geminiApiKey != null ? Colors.white : Colors.yellow.shade600,
            ),
            onPressed: () {
              _showApiKeyDialog();
            },
            tooltip: 'API Anahtarını Ayarla',
          ),
          IconButton(
            icon: Icon(
              _isAutoPlayEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              size: 26,
              color: _isTtsInitialized ? Colors.white : Colors.white38,
            ),
            onPressed: _isTtsInitialized
                ? () {
                    setState(() {
                      _isAutoPlayEnabled = !_isAutoPlayEnabled;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isAutoPlayEnabled
                            ? 'Otomatik seslendirme açıldı.'
                            : 'Otomatik seslendirme kapandı.'),
                        backgroundColor: Colors.teal,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                : null,
            tooltip: _isTtsInitialized
                ? 'Otomatik Seslendirme'
                : 'Ses motoru yükleniyor...',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 26),
            onPressed: () {
              setState(() {
                _displayMessages.clear();
                _chatHistory.clear();
                _displayMessages.add(ChatMessage(
                  role: 'assistant',
                  text:
                      'Merhaba! 👋 Ben Table Intelligence. Size nasıl yardımcı olabilirim?',
                  timestamp: DateTime.now(),
                ));
              });
            },
            tooltip: 'Sohbeti Sıfırla',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.teal.withOpacity(0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _displayMessages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == 0) {
                  return _buildThinkingIndicator();
                }
                final messageIndex = _isLoading ? index - 1 : index;
                final message = _displayMessages[
                    _displayMessages.length - 1 - messageIndex];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    // ... (Bu fonksiyonda değişiklik yok, aynı kalabilir)
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.teal.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _thinkingAnimation,
                      child: const Icon(Icons.psychology_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _thinkingPhase,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _thinkingAnimController,
                      builder: (context, child) {
                        final delay = index * 0.2;
                        final value = (_thinkingAnimController.value - delay)
                            .clamp(0.0, 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                Colors.white.withOpacity(0.3 + (value * 0.7)),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    // ... (Bu fonksiyonda değişiklik yok, aynı kalabilir)
    final isUser = message.role == 'user';
    final isSystem = message.role == 'system';

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.text,
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.teal.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? LinearGradient(
                          colors: [Colors.teal.shade400, Colors.teal.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isUser ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isUser
                        ? const Radius.circular(20)
                        : const Radius.circular(4),
                    bottomRight: isUser
                        ? const Radius.circular(4)
                        : const Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isUser
                          ? Colors.teal.withOpacity(0.3)
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      message.isAnimating
                          ? message.displayedText
                          : message.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF1A1A2E),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isUser &&
                        !message.isAnimating &&
                        _isTtsInitialized) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          _speak(message.text);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.teal.shade100)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  color: Colors.teal.shade700, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                'Seslendir',
                                style: TextStyle(
                                  color: Colors.teal.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (!message.isAnimating) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isUser ? Colors.white70 : Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.teal.shade200, width: 2),
                ),
                child: Icon(Icons.person_rounded,
                    color: Colors.teal.shade700, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    // YENİ: API anahtarı yoksa input alanını farklılaştır
    final bool isApiKeySet = _geminiApiKey != null && _geminiApiKey!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 90), // Dock için boşluk
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: isApiKeySet
                        ? Colors.grey.shade50
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isApiKeySet
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey.shade700,
                    ),
                    decoration: InputDecoration(
                      hintText: isApiKeySet
                          ? "Asistana bir şeyler sorun..."
                          : "Önce API anahtarını ayarlayın...",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Icon(
                          isApiKeySet
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.lock_outline_rounded,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isLoading && isApiKeySet, // YENİ
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: _isLoading || !isApiKeySet // YENİ
                      ? LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade500])
                      : LinearGradient(
                          colors: [Colors.teal.shade400, Colors.teal.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  shape: BoxShape.circle,
                  boxShadow: _isLoading || !isApiKeySet // YENİ
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading || !isApiKeySet
                        ? null
                        : _sendMessage, // YENİ
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              isApiKeySet
                                  ? Icons.send_rounded
                                  : Icons.key_rounded, // YENİ
                              color: Colors.white,
                              size: 24),
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

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class ChatMessage {
  final String role;
  final String text;
  final DateTime timestamp;
  bool isAnimating;
  String displayedText;

  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.isAnimating = false,
  }) : displayedText = isAnimating ? '' : text;
}
