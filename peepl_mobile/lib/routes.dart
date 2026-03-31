import 'package:flutter/material.dart';
import 'screens/post_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/main_shell.dart';
import 'screens/location_detail_screen.dart';
import 'screens/account_info_screen.dart';
import 'screens/create_peep_screen.dart';
import 'screens/deal_claimed_screen.dart';
import 'screens/deals_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/follow_list_screen.dart';
import 'screens/get_peeps_screen.dart';
import 'screens/groups_screen.dart';
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
import 'screens/share_screen.dart';
import 'screens/sign_up_confirmed_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/venue_list_screen.dart';
import 'screens/venue_screen.dart';
import 'screens/vip_peeps_screen.dart';
import 'screens/merchant/how_to_advertise_screen.dart';
import 'screens/merchant/merchant_account_info_screen.dart';
import 'screens/merchant/merchant_account_number_screen.dart';
import 'screens/merchant/merchant_activity_screen.dart';
import 'screens/merchant/merchant_portal_screen.dart';
import 'screens/merchant/merchant_setup_step1_screen.dart';
import 'screens/merchant/merchant_setup_step2_screen.dart';
import 'screens/merchant/merchant_sign_in_screen.dart';

/// Demo post for catalog navigation (does not require Firestore).
final Map<String, dynamic> kLocationDetailDemoPostData = <String, dynamic>{
  'id': 'demo_preview',
  'locationName': 'Sample venue',
  'username': 'Preview user',
  'crowdingLevel': 5,
  'imageUrl': 'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800',
  'description': 'Preview from Admin Screens catalog.',
};

Map<String, WidgetBuilder> appRoutes = {
  '/home': (_) => const MainShell(),
  '/feed': (_) => const MainShell(initialBodyIndex: 0),
  '/discover': (_) => const MainShell(initialBodyIndex: 1),
  '/post': (_) => const PostScreen(),
  '/chat': (_) => const MainShell(initialBodyIndex: 2),
  '/profile': (_) => const MainShell(initialBodyIndex: 3),
  '/settings': (_) => SettingsScreen(),
  '/login': (_) => LoginScreen(),
  '/admin': (_) => const AdminScreen(),
  '/location_detail_demo': (_) => LocationDetailScreen(
        postData: Map<String, dynamic>.from(kLocationDetailDemoPostData),
      ),
  '/account_info': (_) => const AccountInfoScreen(),
  '/create_peep': (_) => const CreatePeepScreen(),
  '/deal_claimed': (_) => const DealClaimedScreen(),
  '/deals': (_) => const DealsScreen(),
  '/favorites': (_) => const FavoritesScreen(),
  '/follow_list': (_) => const FollowListScreen(),
  '/get_peeps': (_) => const GetPeepsScreen(),
  '/groups': (_) => const GroupsScreen(),
  '/invite': (_) => const InviteScreen(),
  '/leaderboard': (_) => const LeaderboardScreen(),
  '/likers': (_) => const LikersScreen(),
  '/map': (_) => const MapScreen(),
  '/menu': (_) => const MenuScreen(),
  '/my_peeps': (_) => const MyPeepsScreen(),
  '/notifications': (_) => const NotificationsScreen(),
  '/onboarding': (_) => const OnboardingScreen(),
  '/peep_detail': (_) => const PeepDetailScreen(),
  '/permissions': (_) => const PermissionsScreen(),
  '/pioneer_congrat': (_) => const PioneerCongratScreen(),
  '/pioneers': (_) => const PioneersScreen(),
  '/report': (_) => const ReportScreen(),
  '/search': (_) => const SearchScreen(),
  '/share': (_) => const ShareScreen(),
  '/sign_up_confirmed': (_) => const SignUpConfirmedScreen(),
  '/user_profile': (_) => const UserProfileScreen(),
  '/venue_list': (_) => const VenueListScreen(),
  '/venue': (_) => const VenueScreen(),
  '/vip_peeps': (_) => const VIPeepsScreen(),
  '/how_to_advertise': (_) => const HowToAdvertiseScreen(),
  '/merchant_account_info': (_) => const MerchantAccountInfoScreen(),
  '/merchant_account_number': (_) => const MerchantAccountNumberScreen(),
  '/merchant_activity': (_) => const MerchantActivityScreen(),
  '/merchant_portal': (_) => const MerchantPortalScreen(),
  '/merchant_setup_step1': (_) => const MerchantSetupStep1Screen(),
  '/merchant_setup_step2': (_) => const MerchantSetupStep2Screen(),
  '/merchant_sign_in': (_) => const MerchantSignInScreen(),
};
