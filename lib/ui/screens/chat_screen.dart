import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

import '../../services/rag_chat_service.dart';
import '../../services/quran_text_db.dart';
import '../../services/quran_translation_pack_service.dart';
import '../../data/surah_name.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const ChatScreen(),
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
            child: child,
          ),
        ),
      );

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = RagChatService.instance;
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  // État traduction
  bool _translationReady = false;
  bool _translationChecked = false;
  bool _downloading = false;
  double _downloadProgress = 0.0;
  CancelToken? _cancelToken;

  static const _gold = Color(0xFFC8A165);
  static const _green = Color(0xFF1B5E20);
  static const _bgColor = Color(0xFFF5F0EA);

  static const _suggestions = [
    'Que dit le Coran sur la patience ?',
    'Versets sur la prière',
    'Comment trouver la paix intérieure ?',
    'Versets sur le pardon et la miséricorde',
    'Que dit le Coran sur la famille ?',
  ];

  @override
  void initState() {
    super.initState();
    _checkTranslation();
  }

  Future<void> _checkTranslation() async {
    final ready = await QuranTranslationPackService.isPackReady(AppLang.fr);
    if (mounted) setState(() { _translationReady = ready; _translationChecked = true; });
  }

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _downloadProgress = 0.0; });
    _cancelToken = CancelToken();
    try {
      await QuranTranslationPackService.downloadPack(
        AppLang.fr,
        cancelToken: _cancelToken,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) setState(() { _translationReady = true; _downloading = false; });
    } catch (_) {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() => _isLoading = true);
    _scrollToBottom();

    await _service.processQuery(query);

    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = _service.history;
    final isEmpty = messages.isEmpty;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: _gold, size: 20),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistant Coranique',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Recherche dans le Coran',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Effacer la conversation',
              onPressed: () {
                _service.clearHistory();
                setState(() {});
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_translationChecked && !_translationReady)
            _DownloadBanner(
              downloading: _downloading,
              progress: _downloadProgress,
              onDownload: _startDownload,
            ),
          Expanded(
            child: isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    itemCount: messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == messages.length) return _TypingIndicator();
                      return _MessageBubble(
                        message: messages[i],
                        onVerseTap: _navigateToVerse,
                      );
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withValues(alpha: 0.1),
              border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
            ),
            child: const Icon(Icons.auto_awesome, color: _gold, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Assistant Coranique',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posez une question et je trouverai les versets '
            'les plus pertinents dans le Coran.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Questions fréquentes',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _green,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._suggestions.map((s) => _SuggestionChip(
                text: s,
                onTap: () => _sendMessage(s),
              )),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                maxLines: null,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ex: patience, prière, pardon...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: _bgColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _isLoading
                ? const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _green,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => _sendMessage(_controller.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _green,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _navigateToVerse(QVerse verse) {
    HapticFeedback.lightImpact();
    // Navigation gérée par le parent si besoin — pour l'instant copie le verset
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${surahFr[verse.surah] ?? 'Sourate ${verse.surah}'} — verset ${verse.ayah}'),
        backgroundColor: _green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Bulle de message ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<QVerse> onVerseTap;

  const _MessageBubble({required this.message, required this.onVerseTap});

  static const _green = Color(0xFF1B5E20);
  static const _gold = Color(0xFFC8A165);

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _green,
              ),
              child: const Icon(Icons.auto_awesome, color: _gold, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? _green : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
                if (message.verses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...message.verses.map((v) => _VerseCard(
                        verse: v,
                        onTap: () => onVerseTap(v),
                      )),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 38),
        ],
      ),
    );
  }
}

// ── Carte verset ──────────────────────────────────────────────────────────────

class _VerseCard extends StatelessWidget {
  final QVerse verse;
  final VoidCallback onTap;

  const _VerseCard({required this.verse, required this.onTap});

  static const _gold = Color(0xFFC8A165);
  static const _green = Color(0xFF1B5E20);

  static String _clean(String text) =>
      text.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  @override
  Widget build(BuildContext context) {
    final surahName = surahFr[verse.surah] ?? 'Sourate ${verse.surah}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gold.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête sourate:ayah
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$surahName ${verse.surah}:${verse.ayah}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.open_in_new, size: 14, color: _gold),
              ],
            ),
            const SizedBox(height: 10),
            // Texte arabe
            if (verse.ar.isNotEmpty)
              Text(
                _clean(verse.ar),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'UthmanTahaNaskh',
                  fontSize: 18,
                  height: 1.8,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            if (verse.fr.isNotEmpty) ...[
              const Divider(height: 16, thickness: 0.5),
              Text(
                _clean(verse.fr),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Suggestions ───────────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC8A165).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: Color(0xFF1B5E20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFC8A165)),
          ],
        ),
      ),
    );
  }
}

// ── Indicateur de frappe ──────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1B5E20),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Color(0xFFC8A165), size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
                    final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(0.3, 1.0);
                    return Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1B5E20).withValues(alpha: opacity),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bannière de téléchargement traduction ─────────────────────────────────────

class _DownloadBanner extends StatelessWidget {
  final bool downloading;
  final double progress;
  final VoidCallback onDownload;

  const _DownloadBanner({
    required this.downloading,
    required this.progress,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFC8A165).withValues(alpha: 0.4),
          ),
        ),
      ),
      child: downloading
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Téléchargement… ${(progress * 100).toStringAsFixed(0)} %',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFDDD0A8),
                    color: const Color(0xFF1B5E20),
                    minHeight: 5,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.download_rounded,
                    color: Color(0xFFC8A165), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'La traduction française est requise pour l\'assistant.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onDownload,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Télécharger'),
                ),
              ],
            ),
    );
  }
}
