import { Venue } from './Venue';

export type PioneerCongratParams = {
  venueName: string;
  venuesPioneedCount: number;
};

export type DealClaimedDeal = {
  merchantName: string;
  offerText: string;
  expiresAt: string;
  venueImageUrl: string;
  adId: string;
};

export type MainTabsParamList = {
  Map: undefined;
  Venues: undefined;
  Profile: undefined;
};

export type RootStackParamList = {
  Login: undefined;
  Register: undefined;
  MainTabs:
    | undefined
    | {
        screen?: keyof MainTabsParamList;
        params?: MainTabsParamList[keyof MainTabsParamList];
      };
  Venue: { venue: Venue };
  CreatePeep: {
    venue?: Venue;
    location?: {
      latitude: number;
      longitude: number;
    };
    venues?: Venue[];
  };
  PioneerCongrats: PioneerCongratParams;
  Deals: undefined;
  DealClaimed: { deal: DealClaimedDeal };
  MerchantSignIn: undefined;
  GetPeeps: undefined;
  Leaderboard: undefined;
  SignUpConfirmed: undefined;
  Onboarding: undefined;
  Permissions: undefined;
  Map: undefined;
  Venues: undefined;
  Profile: undefined;
  Pioneers: undefined;
  UserProfile: { userId: string };
  FollowList: { userId: string; type: 'followers' | 'following' };
  MyPeeps: undefined;
  Favorites: undefined;
  Groups: undefined;
  Settings: undefined;
};
