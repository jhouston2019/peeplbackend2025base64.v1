import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/location_permission_screen.dart';
import 'screens/push_permission_screen.dart';
import 'screens/peep_submitted_screen.dart';
import 'screens/no_connection_screen.dart';
import 'screens/post_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/main_shell.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/location_detail_screen.dart';
import 'screens/account_info_screen.dart';
import 'screens/create_peep_screen.dart';
import 'screens/deal_claimed_screen.dart';
import 'screens/deals_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/follow_list_screen.dart';
import 'screens/get_peeps_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/heat_map_screen.dart';
import 'screens/invite_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/likers_screen.dart';
import 'screens/map_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/my_peeps_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/peep_detail_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/pioneer_congrat_screen.dart';
import 'screens/pioneers_screen.dart';
import 'screens/report_screen.dart';
import 'screens/search_screen.dart';
import 'screens/search_results_screen.dart';
import 'screens/share_screen.dart';
import 'screens/sign_up_confirmed_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/venue_list_screen.dart';
import 'screens/venue_screen.dart';
import 'screens/trending_screen.dart';
import 'screens/vip_peeps_screen.dart';
import 'screens/merchant/merchant_account_info_screen.dart';
import 'screens/merchant/merchant_account_number_screen.dart';
import 'screens/merchant/merchant_activity_screen.dart';
import 'screens/merchant/merchant_portal_screen.dart';
import 'screens/merchant/merchant_setup_step1_screen.dart';
import 'screens/merchant/merchant_setup_step2_screen.dart';
import 'screens/merchant/merchant_sign_in_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/scoreboard_screen.dart';
import 'screens/feed_screen.dart';

/// Demo post for catalog navigation (does not require Firestore).
final Map<String, dynamic> kLocationDetailDemoPostData = <String, dynamic>{
  'id': 'demo_preview',
  'locationName': 'Sample venue',
  'username': 'Preview user',
  'crowdingLevel': 5,
  'imageUrl': 'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800',
  'description': 'Preview from Admin Screens catalog.',
  'venueType': 'Coffee Shop',
  'maleFemaleRatio': 55,
  'adultKidRatio': 80,
  'ageRange': '20s-30s',
  'hasPets': false,
  'latitude': 40.758,
  'longitude': -73.9855,
};

Map<String, WidgetBuilder> appRoutes = {
  '/splash': (_) => const SplashScreen(),
  '/onboarding/1': (_) => const OnboardingScreen(step: 1),
  '/onboarding/2': (_) => const OnboardingScreen(step: 2),
  '/onboarding/3': (_) => const OnboardingScreen(step: 3),
  '/permissions/location': (_) => const LocationPermissionScreen(),
  '/permissions/push': (_) => const PushPermissionScreen(),
  '/peep_submitted': (_) => const PeepSubmittedScreen(),
  '/no_connection': (_) => const NoConnectionScreen(),
  '/home': (_) => const MainShell(),
  '/feed': (_) => const MainShell(initialBodyIndex: 0),
  '/discover': (_) => const MainShell(initialBodyIndex: 1),
  '/post': (_) => const PostScreen(),
  '/chat': (_) => ChatScreen(),
  '/profile': (_) => const ProfileScreen(),
  '/settings': (_) => SettingsScreen(),
  '/login': (_) => LoginScreen(),
  '/admin': (_) => const AdminScreen(),
  '/alerts': (_) => const AlertsScreen(),
  '/location_detail_demo': (_) => LocationDetailScreen(
        postData: Map<String, dynamic>.from(kLocationDetailDemoPostData),
      ),
  '/account_info': (_) => const AccountInfoScreen(),
  '/create_peep': (_) => const CreatePeepScreen(),
  '/deal_claimed': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    final adData =
        args is Map<String, dynamic> ? args : <String, dynamic>{};
    return DealClaimedScreen(adData: adData);
  },
  '/deals': (_) => const DealsScreen(),
  '/explore': (_) => const ExploreScreen(),
  '/favorites': (_) => const FavoritesScreen(),
  '/follow_list': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    final map =
        args is Map<String, dynamic> ? args : <String, dynamic>{};
    return FollowListScreen(
      userId: map['userId'] as String? ?? '',
      mode: map['mode'] as String? ?? 'followers',
    );
  },
  '/get_peeps': (_) => const GetPeepsScreen(),
  '/groups': (_) => const GroupsScreen(),
  '/heat_map': (_) => const HeatMapScreen(),
  '/invite': (_) => const InviteScreen(),
  '/leaderboard': (_) => const LeaderboardScreen(),
  '/scoreboard': (_) => const ScoreboardScreen(),
  '/likers': (_) => const LikersScreen(),
  '/map': (_) => const MapScreen(),
  '/menu': (_) => const MenuScreen(),
  '/my_peeps': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    final userId = args is String ? args : null;
    return MyPeepsScreen(userId: userId);
  },
  '/notifications': (_) => const NotificationsScreen(),
  '/onboarding': (_) => const OnboardingScreen(step: 1),
  '/peep_detail': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    final postData = args is Map<String, dynamic>
        ? args
        : <String, dynamic>{};
    return PeepDetailScreen(postData: postData);
  },
  '/location_detail': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    final postData = args is Map<String, dynamic>
        ? args
        : <String, dynamic>{};
    return LocationDetailScreen(postData: postData);
  },
  '/permissions': (_) => const PermissionsScreen(),
  '/pioneer_congrat': (_) => const PioneerCongratScreen(),
  '/pioneers': (_) => const PioneersScreen(),
  '/report': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      return ReportScreen(
        postId: args['postId'] as String?,
        reportedUserId: args['reportedUserId'] as String?,
      );
    }
    final postId = args is String ? args : '';
    return ReportScreen(postId: postId);
  },
  '/search_results': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    final query = args is String ? args : '';
    return SearchResultsScreen(query: query);
  },
  '/search': (_) => const SearchScreen(),
  '/share': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    final postData =
        args is Map<String, dynamic> ? args : <String, dynamic>{};
    return ShareScreen(postData: postData);
  },
  '/sign_up_confirmed': (_) => const SignUpConfirmedScreen(),
  '/user_profile': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    final userId = args is String
        ? args
        : (args as Map?)?['userId'] as String? ?? '';
    return UserProfileScreen(userId: userId);
  },
  '/venue_list': (_) => const VenueListScreen(),
  '/venue': (_) => const VenueScreen(),
  '/trending': (_) => const TrendingScreen(),
  '/vip_peeps': (_) => const VIPeepsScreen(),
  '/how_to_advertise': (_) => const MerchantPortalScreen(),
  '/merchant_account_info': (_) => const MerchantAccountInfoScreen(),
  '/merchant_account_number': (_) => const MerchantAccountNumberScreen(),
  '/merchant_activity': (_) => const MerchantActivityScreen(),
  '/merchant_portal': (_) => const MerchantPortalScreen(),
  '/merchant_setup_step1': (_) => const MerchantSetupStep1Screen(),
  '/merchant_setup_step2': (_) => const MerchantSetupStep2Screen(),
  '/merchant_setup_step3': (_) => const MerchantSetupStep2Screen(),
  '/merchant_sign_in': (_) => const MerchantSignInScreen(),
  '/gallery': (_) => const GalleryScreen(),
  if (kDebugMode && kIsWeb) '/feed_preview': (_) => const FeedPreviewHost(),
};
