export interface Venue {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  category: string;
  description?: string;
  imageUrl?: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  isActive: boolean;
  peepCount: number;
  averageRating: number;
  totalRatings: number;
  distance?: number; // Calculated distance from user
}

export interface CreateVenueData {
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  category: string;
  description?: string;
}
