import { Venue } from './Venue';

export type RootStackParamList = {
  Login: undefined;
  Register: undefined;
  MainTabs: undefined;
  Venue: { venue: Venue };
  CreatePeep: {
    venue?: Venue;
    location?: {
      latitude: number;
      longitude: number;
    };
    venues?: Venue[];
  };
  Map: undefined;
  Venues: undefined;
  Profile: undefined;
};
