import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/token_storage.dart';

class ChatMessage {
  final String id;
  final String senderID;
  final String content;
  final DateTime createdAt;
  const ChatMessage({
    required this.id,
    required this.senderID,
    required this.content,
    required this.createdAt,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        senderID: j['sender_id'] as String,
        content: j['content'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
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

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  String? _myId;
  bool _sending = false;
  bool _historyLoaded = false;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _loadMyId();
    _loadHistory();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
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
      } else if (mounted) {
        setState(() => _historyLoaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _historyLoaded = true);
    }
  }

  void listenToWS(Stream<Map<String, dynamic>> wsStream) {
    _wsSub = wsStream.listen((msg) {
      if (msg['type'] == 'chat_message' && mounted) {
        final payload = msg['payload'] as Map<String, dynamic>;
        if (payload['ride_request_id'] == widget.rideRequestId) {
          setState(() {
            _messages.add(ChatMessage.fromJson(payload));
          });
          _scrollToBottom();
        }
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

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
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
            const Text(
              'Active trip',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: 5,
                    itemBuilder: (_, __) => Shimmer.fromColors(
                      baseColor: AppColors.surface,
                      highlightColor: AppColors.border,
                      child: Container(
                        height: 40,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                            const Text(
                              'No messages yet.\nSay hello!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
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
                      hintText: 'Message…',
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
        child: Text(
          msg.content,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
