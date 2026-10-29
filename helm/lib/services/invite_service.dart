import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

enum InviteStatus { pendingAuth, success, alreadyMember, failed }

class InviteEvent {
  final String communityId;
  final InviteStatus status;
  final String message;

  const InviteEvent({
    required this.communityId,
    required this.status,
    required this.message,
  });
}

class InviteService {
  static final InviteService _instance = InviteService._internal();
  factory InviteService() => _instance;
  InviteService._internal();

  final _appLinks = AppLinks();
  final _supabaseService = SupabaseService();

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  StreamSubscription<Uri>? _linkSubscription;
  String? pendingCommunityId;
  final _inviteController = StreamController<String>.broadcast();
  final _eventController = StreamController<InviteEvent>.broadcast();

  Stream<String> get onInviteReceived => _inviteController.stream;
  Stream<InviteEvent> get onInviteEvent => _eventController.stream;

  /// Extracts communityId from custom schemes (waypoint://, helm://) or web URLs
  static String? extractCommunityId(Uri uri) {
    if (uri.queryParameters.containsKey('communityId')) {
      final id = uri.queryParameters['communityId']?.trim();
      if (id != null && id.isNotEmpty) return id;
    }

    if ((uri.scheme == 'waypoint' || uri.scheme == 'helm') && uri.host == 'invite') {
      final id = uri.queryParameters['communityId']?.trim();
      if (id != null && id.isNotEmpty) return id;
    }

    // Support /invite/{id} path pattern
    final segments = uri.pathSegments;
    final inviteIndex = segments.indexOf('invite');
    if (inviteIndex != -1 && inviteIndex + 1 < segments.length) {
      final id = segments[inviteIndex + 1].trim();
      if (id.isNotEmpty) return id;
    }

    return null;
  }

  /// Initialize deep link listening.
  Future<void> init() async {
    // 1. Web cold start check
    if (kIsWeb) {
      final initialId = extractCommunityId(Uri.base);
      if (initialId != null) {
        _handleCommunityId(initialId);
      }
    }

    // 2. Mobile/Desktop cold start
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink);
      }
    } catch (e) {
      debugPrint('InviteService: Error fetching initial link: $e');
    }

    // 3. App open / background deep link stream
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleLink(uri),
      onError: (err) => debugPrint('InviteService: uriLinkStream error: $err'),
    );

    // 4. Auth change listener: Auto-join pending community upon sign-in
    _supabase?.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && pendingCommunityId != null) {
        final id = pendingCommunityId!;
        pendingCommunityId = null;
        processJoin(id);
      }
    });
  }

  void _handleLink(Uri uri) {
    debugPrint('InviteService: Processing Deep Link: $uri');
    final communityId = extractCommunityId(uri);
    if (communityId != null) {
      _handleCommunityId(communityId);
    }
  }

  void _handleCommunityId(String communityId) {
    _inviteController.add(communityId);
    processJoin(communityId);
  }

  Future<InviteEvent> processJoin(String communityId) async {
    final client = _supabase;
    if (client == null) {
      pendingCommunityId = communityId;
      return InviteEvent(
        communityId: communityId,
        status: InviteStatus.pendingAuth,
        message: 'Sign in to join community.',
      );
    }

    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      pendingCommunityId = communityId;
      final event = InviteEvent(
        communityId: communityId,
        status: InviteStatus.pendingAuth,
        message: 'Sign in to join community.',
      );
      _eventController.add(event);
      return event;
    }

    try {
      // Check if already a member
      final existing = await client
          .from('community_members')
          .select('id')
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        final event = InviteEvent(
          communityId: communityId,
          status: InviteStatus.alreadyMember,
          message: 'Already a member of this community.',
        );
        _eventController.add(event);
        return event;
      }

      await _supabaseService.joinCommunity(communityId);
      final event = InviteEvent(
        communityId: communityId,
        status: InviteStatus.success,
        message: 'Joined community successfully!',
      );
      _eventController.add(event);
      return event;
    } catch (e) {
      debugPrint('InviteService: Error joining community: $e');
      final event = InviteEvent(
        communityId: communityId,
        status: InviteStatus.failed,
        message: 'Failed to join community: $e',
      );
      _eventController.add(event);
      return event;
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
