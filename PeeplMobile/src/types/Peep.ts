export interface Peep {
  id: string;
  venueId: string;
  userId: string;
  description: string;
  rating?: number;
  latitude?: number;
  longitude?: number;
  imageUrl?: string;
  createdAt: string;
  updatedAt: string;
  isActive: boolean;
  likeCount: number;
  commentCount: number;
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
  rating?: number;
  latitude?: number;
  longitude?: number;
  image?: {
    uri: string;
    type: string;
    name: string;
  };
}
