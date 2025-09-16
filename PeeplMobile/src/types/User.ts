export interface User {
  uid: string;
  email: string;
  username: string;
  firstName: string;
  lastName: string;
  profileImageUrl?: string;
  bio?: string;
  location?: {
    latitude: number;
    longitude: number;
  };
  preferences: {
    notifications: boolean;
    locationSharing: boolean;
    publicProfile: boolean;
  };
  createdAt: string;
  updatedAt: string;
  isActive: boolean;
}

export interface AuthResponse {
  success: boolean;
  token?: string;
  user?: User;
  error?: string;
}

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface RegisterData {
  email: string;
  password: string;
  username: string;
  firstName: string;
  lastName: string;
}
