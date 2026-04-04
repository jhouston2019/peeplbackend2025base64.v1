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

/** Merchant document from merchant_accounts (API / Firestore). */
export type MerchantDoc = {
  id: string;
  businessName?: string;
  merchantNumber?: string;
  category?: string;
  address?: string;
  city?: string;
  contactName?: string;
  email?: string;
  phone?: string;
  paymentLast4?: string | null;
  isActive?: boolean;
  [key: string]: unknown;
};

export type MerchantSetupStep1Data = {
  businessName: string;
  address: string;
  city: string;
  category:
    | 'bar_pub'
    | 'restaurant'
    | 'coffee'
    | 'retail'
    | 'services'
    | 'entertainment'
    | 'other';
};

export type MainTabsParamList = {
  Feed: undefined;
  Deals: undefined;
  GetPeeps: undefined;
  Leaders: undefined;
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
    venueId?: string;
    venueName?: string;
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
  MerchantSetupStep1: undefined;
  MerchantSetupStep2: { step1: MerchantSetupStep1Data };
  MerchantAccountNumber: {
    merchantId: string;
    merchantNumber: string;
    businessName: string;
    address: string;
    city: string;
    category: string;
    contactName: string;
    email: string;
    phone: string;
  };
  MerchantPortal: { merchant: MerchantDoc };
  MerchantActivity: { merchantId: string };
  MerchantAccountInfo: { merchant: MerchantDoc };
  HowToAdvertise: undefined;
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
  PeepDetail: { peepId: string };
  Likers: { peepId: string };
  Share: { peepId: string };
  Invite: undefined;
  Search: undefined;
  Notifications: undefined;
  AccountInfo: undefined;
  VIPeeps: undefined;
  Report: { peepId: string };
};
