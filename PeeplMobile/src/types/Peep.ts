export interface Peep {
  id: string;
  venueId: string;
  userId: string;
  description: string;
  crowdSize: 1 | 2 | 3 | 4 | 5;
  mfRatio: number;
  akRatio: number;
  ageRanges: string[];
  vibe: string[];
  crowdTrend: 'getting_busier' | 'steady' | 'clearing_out';
  latitude?: number;
  longitude?: number;
  imageUrl?: string;
  createdAt: string;
  updatedAt: string;
  isActive: boolean;
  likeCount: number;
  commentCount: number;
  isPioneer?: boolean;
  user?: {
    username: string;
    firstName: string;
    lastName: string;
    profileImageUrl?: string;
  };
  venue?: {
    name: string;
    address: string;
  };
}

export interface CreatePeepData {
  venueId: string;
  description: string;
  crowdSize: 1 | 2 | 3 | 4 | 5;
  mfRatio: number;
  akRatio: number;
  ageRanges: string[];
  vibe: string[];
  crowdTrend: 'getting_busier' | 'steady' | 'clearing_out';
  latitude?: number;
  longitude?: number;
  image?: {
    uri: string;
    type: string;
    name: string;
  };
}
