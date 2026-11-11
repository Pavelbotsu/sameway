import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/token_storage.dart';
import '../../core/widgets/user_avatar.dart';
import 'chat_screen.dart';

/// Recent-conversations list (Round 2 §3): every persistent pair thread the
/// user has, newest activity first, with unread badges. Entry point lives in
/// both home screens' account/menu area.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _Conversation {
  final String id;
  final String peerId;
  final String peerName;
  final String peerPhotoUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool hasRideHistory;

  const _Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.peerPhotoUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.hasRideHistory,
  });

  factory _Conversation.fromJson(Map<String, dynamic> j) => _Conversation(
        id: j['id'] as String,
        peerId: j['peer_id'] as String,
        peerName: j['peer_name'] as String? ?? '',
        peerPhotoUrl: j['peer_photo_url'] as String? ?? '',
        lastMessage: j['last_message'] as String? ?? '',
        lastMessageAt: j['last_message_at'] == null
            ? null
            : DateTime.tryParse(j['last_message_at'] as String),
        unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
        hasRideHistory: j['has_ride_history'] as bool? ?? false,
      );
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<_Conversation> _conversations = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.get(
        Uri.parse('$kApiBase/chat/conversations'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (resp.statusCode == 200 && mounted) {
        final list = jsonDecode(resp.body) as List;
        setState(() {
          _conversations = list
              .map((e) => _Conversation.fromJson(e as Map<String, dynamic>))
              .toList();
          _loaded = true;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  String _relativeTime(BuildContext context, DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${t.day}.${t.month}.${t.year}';
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
        title: Text(
          l.messagesTitle,
          style: const TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : _conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.forum_outlined,
                            color: AppColors.border, size: 52),
                        const SizedBox(height: 14),
                        Text(
                          l.noConversations,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.noConversationsDesc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.teal,
                  backgroundColor: AppColors.surface,
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: AppColors.border, height: 1, indent: 76),
                    itemBuilder: (_, i) {
                      final conv = _conversations[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: UserAvatar(
                          photoUrl: conv.peerPhotoUrl.isEmpty
                              ? null
                              : conv.peerPhotoUrl,
                          name: conv.peerName,
                          size: 44,
                        ),
                        title: Text(
                          conv.peerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: conv.lastMessage.isEmpty
                            ? null
                            : Text(
                                conv.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: conv.unreadCount > 0
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: conv.unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _relativeTime(context, conv.lastMessageAt),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            if (conv.unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.teal,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${conv.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: conv.id,
                                peerId: conv.peerId,
                                otherPartyName: conv.peerName,
                              ),
                            ),
                          );
                          _load(); // refresh unread counts on return
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
