import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import auth from '@react-native-firebase/auth';
import { User, AuthResponse, LoginCredentials, RegisterData } from '../types/User';

export const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000';

export class AuthService {
  private static instance: AuthService;
  private token: string | null = null;

  public static getInstance(): AuthService {
    if (!AuthService.instance) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  async getIdToken(): Promise<string | null> {
    try {
      const currentUser = auth().currentUser;
      if (currentUser) {
        return await currentUser.getIdToken();
      }
      return null;
    } catch (error) {
      console.error('Get ID token error:', error);
      return null;
    }
  }

  private async getAuthHeaders() {
    const token = await this.getIdToken();
    return {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    };
  }

  async login(credentials: LoginCredentials): Promise<AuthResponse> {
    try {
      const { email, password } = credentials;
      const userCredential = await auth().signInWithEmailAndPassword(email, password);
      const idToken = await userCredential.user.getIdToken();
      
      await AsyncStorage.setItem('authToken', idToken);
      this.token = idToken;

      return {
        success: true,
        token: idToken,
        user: {
          uid: userCredential.user.uid,
          email: userCredential.user.email || email,
          username: '',
          firstName: '',
          lastName: '',
        },
      };
    } catch (error: any) {
      return {
        success: false,
        error: error.message || 'Login failed',
      };
    }
  }

  async register(userData: RegisterData): Promise<AuthResponse> {
    try {
      const { email, password, username, firstName, lastName } = userData;
      
      const userCredential = await auth().createUserWithEmailAndPassword(email, password);
      const idToken = await userCredential.user.getIdToken();
      
      await AsyncStorage.setItem('authToken', idToken);
      this.token = idToken;

      const headers = await this.getAuthHeaders();
      await axios.post(`${API_BASE_URL}/auth/register`, {
        email,
        username,
        firstName,
        lastName
      }, { headers });

      return {
        success: true,
        token: idToken,
        user: {
          uid: userCredential.user.uid,
          email: userCredential.user.email || email,
          username,
          firstName,
          lastName,
        },
      };
    } catch (error: any) {
      return {
        success: false,
        error: error.message || 'Registration failed',
      };
    }
  }

  async getCurrentUser(): Promise<User | null> {
    try {
      const headers = await this.getAuthHeaders();
      const response = await axios.get(`${API_BASE_URL}/users/profile`, { headers });
      return response.data;
    } catch (error) {
      console.error('Get current user error:', error);
      return null;
    }
  }

  async updateProfile(profileData: Partial<User>): Promise<boolean> {
    try {
      const headers = await this.getAuthHeaders();
      await axios.put(`${API_BASE_URL}/users/profile`, profileData, { headers });
      return true;
    } catch (error) {
      console.error('Update profile error:', error);
      return false;
    }
  }

  async logout(): Promise<void> {
    await auth().signOut();
    await AsyncStorage.removeItem('authToken');
    this.token = null;
  }

  /** Alias for logout (settings / sign-out flows). */
  async signOut(): Promise<void> {
    return this.logout();
  }

  async isAuthenticated(): Promise<boolean> {
    const currentUser = auth().currentUser;
    return !!currentUser;
  }
}

export const authService = AuthService.getInstance();
