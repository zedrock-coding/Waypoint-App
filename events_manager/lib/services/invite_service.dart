import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class InviteService {
  static final InviteService _instance = InviteService._internal();
  factory InviteService() => _instance;
  InviteService._internal();

  final _appLinks = AppLinks();
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();
  
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingCommunityId;

  /// Initialize deep link listening.
  Future<void> init() async {
    // 1. Handle Cold Start (App closed)
    // Note: In app_links 6.0.0+, getInitialAppLink was renamed to getInitialLink
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleLink(initialLink);
    }

    // 2. Handle Background (App open)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    });

    // 3. Auth Listener: Join pending community if user logs in
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && _pendingCommunityId != null) {
        _processJoin(_pendingCommunityId!);
        _pendingCommunityId = null;
      }
    });
  }

  void _handleLink(Uri uri) {
    debugPrint('Processing Deep Link: $uri');
    
    if (uri.scheme == 'helm' && uri.host == 'invite') {
      final communityId = uri.queryParameters['communityId'];
      if (communityId != null) {
        _processJoin(communityId);
      }
    }
  }

  Future<void> _processJoin(String communityId) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      // User not logged in: Store ID and wait for auth
      debugPrint('User not logged in. Storing pending invite for: $communityId');
      _pendingCommunityId = communityId;
      // Note: You should trigger a navigation to login/onboarding here if not already there.
      return;
    }

    try {
      await _supabaseService.joinCommunity(communityId);
      debugPrint('Successfully joined community: $communityId');
    } catch (e) {
      debugPrint('Error joining community from link: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
