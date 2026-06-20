import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/haptics.dart';
import '../../core/token_storage.dart';

class ChatMessage {
  final String id;
  final String senderID;
  final String content;
  final DateTime createdAt;
  // Server-stamped when the *other* party's MarkRead runs against this row.
  // Drives the ✓ → ✓✓ flip on the sender's outbound bubbles. Null = unread.
  final DateTime? readAt;
  const ChatMessage({
    required this.id,
    required this.senderID,
    required this.content,
    required this.createdAt,
    this.readAt,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        senderID: j['sender_id'] as String,
        content: j['content'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        readAt: j['read_at'] == null
            ? null
            : DateTime.tryParse(j['read_at'] as String),
      );

  ChatMessage copyWithRead(DateTime when) => ChatMessage(
        id: id,
        senderID: senderID,
        content: content,
        createdAt: createdAt,
        readAt: when,
      );

  /// Sentinel placeholder for Skeletonizer. Alternates the senderID hash
  /// across an index so a mixed me/them rendering can be simulated.
  factory ChatMessage.skeleton({String? sender}) => ChatMessage(
        id: '',
        senderID: sender ?? 'them',
        content: 'Loading message content placeholder.',
        createdAt: DateTime.now(),
      );
}

class ChatScreen extends StatefulWidget {
  final String rideRequestId;
  final String otherPartyName;

  const ChatScreen({
    super.key,
    required this.rideRequestId,
    required this.otherPartyName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  String? _myId;
  bool _sending = false;
  bool _historyLoaded = false;
  StreamSubscription? _wsSub;

  // Typing-indicator state. _otherTyping is true for ~3 s after the most
  // recent inbound chat_typing:true event; _typingClear is the timer that
  // clears it. _lastTypingSent throttles outbound emits to one every 1.2 s
  // while the user is still typing (we also fire one when the field empties).
  bool _otherTyping = false;
  Timer? _typingClear;
  Timer? _typingIdleStop;
  DateTime _lastTypingSent =
      DateTime.fromMillisecondsSinceEpoch(0);
  bool _lastEmittedTypingState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.addListener(_onTextChanged);
    _loadMyId();
    _loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingClear?.cancel();
    _typingIdleStop?.cancel();
    _wsSub?.cancel();
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-mark unread inbound messages on resume — the user is looking at the
    // chat again, so any received-while-backgrounded entries should flip.
    if (state == AppLifecycleState.resumed && mounted) {
      _markRead();
    }
  }

  Future<void> _loadMyId() async {
    _myId = await TokenStorage().getUserId();
  }

  Future<void> _loadHistory() async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.get(
        Uri.parse('$kApiBase/chat/${widget.rideRequestId}'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (resp.statusCode == 200 && mounted) {
        final list = jsonDecode(resp.body) as List;
        setState(() {
          _messages = list
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
          _historyLoaded = true;
        });
        _scrollToBottom();
        _markRead();
      } else if (mounted) {
        setState(() => _historyLoaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _historyLoaded = true);
    }
  }

  void listenToWS(Stream<Map<String, dynamic>> wsStream) {
    _wsSub = wsStream.listen((msg) {
      if (!mounted) return;
      final type = msg['type'];
      final payload = msg['payload'] as Map<String, dynamic>?;
      if (payload == null) return;
      if (payload['ride_request_id'] != widget.rideRequestId) return;
      switch (type) {
        case 'chat_message':
          setState(() {
            _messages.add(ChatMessage.fromJson(payload));
          });
          _scrollToBottom();
          _markRead();
          break;
        case 'chat_typing':
          final from = payload['user_id'] as String?;
          if (from == null || from == _myId) break;
          final typing = payload['typing'] == true;
          _typingClear?.cancel();
          if (typing) {
            setState(() => _otherTyping = true);
            _typingClear = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _otherTyping = false);
            });
          } else {
            setState(() => _otherTyping = false);
          }
          break;
        case 'message_read':
          final ids = (payload['message_ids'] as List?)?.cast<String>() ?? [];
          if (ids.isEmpty) break;
          final whenRaw = payload['read_at'] as String?;
          final when = whenRaw == null
              ? DateTime.now()
              : (DateTime.tryParse(whenRaw) ?? DateTime.now());
          setState(() {
            final lookup = ids.toSet();
            _messages = [
              for (final m in _messages)
                lookup.contains(m.id) ? m.copyWithRead(when) : m,
            ];
          });
          break;
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Debounced keystroke → chat_typing:true emit, with a trailing :false after
  // ~1.5 s of inactivity. We throttle :true emits to one per 1.2 s so a flurry
  // of keystrokes doesn't flood the WS hub.
  void _onTextChanged() {
    final hasText = _ctrl.text.trim().isNotEmpty;
    _typingIdleStop?.cancel();
    if (hasText) {
      final now = DateTime.now();
      if (!_lastEmittedTypingState ||
          now.difference(_lastTypingSent) >
              const Duration(milliseconds: 1200)) {
        _emitTyping(true);
      }
      _typingIdleStop = Timer(const Duration(milliseconds: 1500), () {
        _emitTyping(false);
      });
    } else if (_lastEmittedTypingState) {
      _emitTyping(false);
    }
  }

  Future<void> _emitTyping(bool typing) async {
    _lastEmittedTypingState = typing;
    _lastTypingSent = DateTime.now();
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      await http.post(
        Uri.parse('$kApiBase/chat/typing'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ride_request_id': widget.rideRequestId,
          'typing': typing,
        }),
      );
    } catch (_) {/* silent — best-effort UX hint */}
  }

  Future<void> _markRead() async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      await http.post(
        Uri.parse('$kApiBase/chat/read'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ride_request_id': widget.rideRequestId}),
      );
    } catch (_) {/* silent — server will retry-flip on next message */}
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    Haptics.tap();
    setState(() => _sending = true);
    // Cancel any pending typing-stop emit; the server already considers the
    // sender "not typing" once a message is committed.
    _typingIdleStop?.cancel();
    if (_lastEmittedTypingState) {
      _emitTyping(false);
    }
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/chat/send'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ride_request_id': widget.rideRequestId,
          'content': text,
        }),
      );
      if (resp.statusCode == 200 && mounted) {
        final msg = ChatMessage.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
        setState(() {
          _messages.add(msg);
          _ctrl.clear();
        });
        _scrollToBottom();
      }
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherPartyName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              l.activeTrip,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: !_historyLoaded
                ? Skeletonizer(
                    enabled: true,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: 5,
                      itemBuilder: (_, i) => _MessageBubble(
                        msg: ChatMessage.skeleton(
                          sender: i.isEven ? 'them' : '',
                        ),
                        myId: '',
                      ),
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                color: AppColors.border, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              l.noMessages,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _MessageBubble(
                            msg: _messages[i], myId: _myId ?? ''),
                      ),
          ),
          // Typing indicator pill. Reserves a fixed slot so the input field
          // doesn't shift up/down when the indicator appears/disappears.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _otherTyping
                ? Padding(
                    key: const ValueKey('typing'),
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Row(
                      children: [
                        const _TypingDots(),
                        const SizedBox(width: 8),
                        Text(
                          l.typing(widget.otherPartyName),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: l.messageHint,
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final String myId;
  const _MessageBubble({required this.msg, required this.myId});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.senderID == myId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: isMe
              ? null
              : Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (isMe && msg.id.isNotEmpty) ...[
              const SizedBox(height: 4),
              Icon(
                msg.readAt != null
                    ? Icons.done_all_rounded
                    : Icons.done_rounded,
                size: 14,
                // ✓✓ goes bright when read; single ✓ stays muted.
                color: msg.readAt != null
                    ? AppColors.teal
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Three-dot animated indicator next to "X is typing…". Lightweight —
/// uses a single AnimationController and offsets each dot's opacity.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_ctrl.value - i * 0.15) % 1.0;
          final alpha = (1 - (phase - 0.5).abs() * 2).clamp(0.25, 1.0);
          return Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 3),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: alpha),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
