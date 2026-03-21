import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Image,
  Alert,
  ActivityIndicator,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import axios from 'axios';
import auth from '@react-native-firebase/auth';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../types/Navigation';
import { User } from '../types/User';
import { Venue } from '../types/Venue';
import { authService } from '../services/AuthService';

const API_BASE_URL = __DEV__
  ? 'http://localhost:3000'
  : 'https://your-production-api.com';

const PRIMARY = '#1565C0';
const ACCENT = '#FFC107';

interface FavoriteVenueRow {
  venueId: string;
  name?: string;
  currentCrowdSize: number | null;
  lastPeepAt?: unknown;
  [key: string]: unknown;
}

interface ProfileScreenProps {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Profile'>;
}

export default function ProfileScreen({ navigation }: ProfileScreenProps) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [favorites, setFavorites] = useState<FavoriteVenueRow[]>([]);
  const [favoritesLoading, setFavoritesLoading] = useState(false);

  useEffect(() => {
    loadUserProfile();
  }, []);

  const loadUserProfile = async () => {
    try {
      const userData = await authService.getCurrentUser();
      setUser(userData);
    } catch (error) {
      console.error('Error loading user profile:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const getAuthHeaders = async () => {
    const token = await auth().currentUser?.getIdToken();
    return {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    };
  };

  const loadFavorites = useCallback(async () => {
    setFavoritesLoading(true);
    try {
      const headers = await getAuthHeaders();
      const res = await axios.get<{ favorites: FavoriteVenueRow[] }>(
        `${API_BASE_URL}/users/favorites`,
        { headers }
      );
      setFavorites(res.data.favorites || []);
    } catch (error) {
      console.error('Error loading favorites:', error);
      Alert.alert('Error', 'Could not load favorite venues.');
    } finally {
      setFavoritesLoading(false);
    }
  }, []);

  useEffect(() => {
    if (user) {
      loadFavorites();
    }
  }, [user, loadFavorites]);

  const handleLogout = async () => {
    Alert.alert(
      'Logout',
      'Are you sure you want to logout?',
      [
        {
          text: 'Cancel',
          style: 'cancel',
        },
        {
          text: 'Logout',
          style: 'destructive',
          onPress: async () => {
            await authService.logout();
            // Navigation will be handled by App.tsx
          },
        },
      ]
    );
  };

  const handleEditProfile = () => {
    Alert.alert('Edit Profile', 'Profile editing feature coming soon!');
  };

  const handleSettings = () => {
    Alert.alert('Settings', 'Settings feature coming soon!');
  };

  const handleMyPeeps = () => {
    Alert.alert('My Peeps', 'My peeps feature coming soon!');
  };

  const handleRemoveFavorite = async (venueId: string) => {
    try {
      const headers = await getAuthHeaders();
      await axios.delete(`${API_BASE_URL}/users/favorites/${venueId}`, { headers });
      setFavorites((prev) => prev.filter((v) => v.venueId !== venueId));
    } catch (error) {
      console.error('Error removing favorite:', error);
      Alert.alert('Error', 'Could not remove this favorite.');
    }
  };

  const openVenue = (item: FavoriteVenueRow) => {
    const lat =
      typeof item.latitude === 'number'
        ? item.latitude
        : typeof item.lat === 'number'
          ? item.lat
          : 0;
    const lng =
      typeof item.longitude === 'number'
        ? item.longitude
        : typeof item.lng === 'number'
          ? item.lng
          : 0;
    const venue: Venue = {
      id: item.venueId,
      name: (item.name as string) || 'Venue',
      address: (item.address as string) || '',
      latitude: lat,
      longitude: lng,
      category: (item.category as string) || '',
      createdBy: (item.createdBy as string) || '',
      createdAt: (item.createdAt as string) || '',
      updatedAt: (item.updatedAt as string) || '',
      isActive: (item.isActive as boolean) ?? true,
      peepCount: (item.peepCount as number) || 0,
      averageRating: (item.averageRating as number) || 0,
      totalRatings: (item.totalRatings as number) || 0,
      description: item.description as string | undefined,
      imageUrl: item.imageUrl as string | undefined,
    };
    navigation.navigate('Venue', { venue });
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <Text>Loading profile...</Text>
      </View>
    );
  }

  if (!user) {
    return (
      <View style={styles.errorContainer}>
        <Text>Error loading profile</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      {/* Profile Header */}
      <View style={styles.header}>
        <View style={styles.profileImageContainer}>
          {user.profileImageUrl ? (
            <Image source={{ uri: user.profileImageUrl }} style={styles.profileImage} />
          ) : (
            <View style={styles.defaultProfileImage}>
              <Icon name="person" size={40} color="#666" />
            </View>
          )}
        </View>

        <Text style={styles.userName}>
          {user.firstName} {user.lastName}
        </Text>
        <Text style={styles.userHandle}>@{user.username}</Text>
        <Text style={styles.userEmail}>{user.email}</Text>

        {user.bio && (
          <Text style={styles.userBio}>{user.bio}</Text>
        )}

        <TouchableOpacity style={styles.editProfileButton} onPress={handleEditProfile}>
          <Icon name="edit" size={16} color="#007AFF" />
          <Text style={styles.editProfileButtonText}>Edit Profile</Text>
        </TouchableOpacity>
      </View>

      {/* Stats */}
      <View style={styles.statsContainer}>
        <View style={styles.stat}>
          <Text style={styles.statNumber}>0</Text>
          <Text style={styles.statLabel}>Peeps</Text>
        </View>
        <View style={styles.stat}>
          <Text style={styles.statNumber}>0</Text>
          <Text style={styles.statLabel}>Following</Text>
        </View>
        <View style={styles.stat}>
          <Text style={styles.statNumber}>0</Text>
          <Text style={styles.statLabel}>Followers</Text>
        </View>
      </View>

      {/* Favorites */}
      <View style={styles.favoritesSection}>
        <View style={styles.favoritesSectionHeader}>
          <Text style={styles.favoritesSectionTitle}>Favorites</Text>
          <TouchableOpacity onPress={() => loadFavorites()} accessibilityRole="button">
            <Icon name="refresh" size={22} color={PRIMARY} />
          </TouchableOpacity>
        </View>
        {favoritesLoading && favorites.length === 0 ? (
          <View style={styles.favoritesSectionLoading}>
            <ActivityIndicator color={ACCENT} />
          </View>
        ) : favorites.length === 0 ? (
          <Text style={styles.favoritesEmptyInline}>No favorite venues yet.</Text>
        ) : (
          favorites.map((item) => (
            <View key={item.venueId} style={styles.favoriteRow}>
              <TouchableOpacity
                style={styles.favoriteRowMain}
                onPress={() => openVenue(item)}
                activeOpacity={0.7}
              >
                <Icon name="place" size={22} color={PRIMARY} />
                <View style={styles.favoriteRowText}>
                  <Text style={styles.favoriteName}>{item.name || 'Venue'}</Text>
                  <Text style={styles.favoriteCrowd}>
                    {item.currentCrowdSize != null
                      ? `Current crowd: ${item.currentCrowdSize}/5`
                      : 'No recent peep'}
                  </Text>
                </View>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.favoriteHeart}
                onPress={() => handleRemoveFavorite(item.venueId)}
                accessibilityRole="button"
                accessibilityLabel={`Unfavorite ${item.name || 'venue'}`}
              >
                <Icon name="favorite" size={26} color={ACCENT} />
              </TouchableOpacity>
            </View>
          ))
        )}
      </View>

      {/* Menu Items */}
      <View style={styles.menuContainer}>
        <TouchableOpacity style={styles.menuItem} onPress={handleMyPeeps}>
          <Icon name="chat-bubble-outline" size={24} color="#007AFF" />
          <Text style={styles.menuItemText}>My Peeps</Text>
          <Icon name="chevron-right" size={24} color="#CCCCCC" />
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem} onPress={handleSettings}>
          <Icon name="settings" size={24} color="#007AFF" />
          <Text style={styles.menuItemText}>Settings</Text>
          <Icon name="chevron-right" size={24} color="#CCCCCC" />
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem}>
          <Icon name="help-outline" size={24} color="#007AFF" />
          <Text style={styles.menuItemText}>Help & Support</Text>
          <Icon name="chevron-right" size={24} color="#CCCCCC" />
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem}>
          <Icon name="info-outline" size={24} color="#007AFF" />
          <Text style={styles.menuItemText}>About</Text>
          <Icon name="chevron-right" size={24} color="#CCCCCC" />
        </TouchableOpacity>
      </View>

      {/* Logout Button */}
      <View style={styles.logoutContainer}>
        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
          <Icon name="logout" size={20} color="#FF3B30" />
          <Text style={styles.logoutButtonText}>Logout</Text>
        </TouchableOpacity>
      </View>

      {/* App Version */}
      <View style={styles.versionContainer}>
        <Text style={styles.versionText}>Peepl 2025 v2.0.0</Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  header: {
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#f8f9fa',
  },
  profileImageContainer: {
    marginBottom: 16,
  },
  profileImage: {
    width: 100,
    height: 100,
    borderRadius: 50,
  },
  defaultProfileImage: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#E0E0E0',
    justifyContent: 'center',
    alignItems: 'center',
  },
  userName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  userHandle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 4,
  },
  userEmail: {
    fontSize: 14,
    color: '#999',
    marginBottom: 8,
  },
  userBio: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    lineHeight: 20,
    marginBottom: 16,
  },
  editProfileButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderWidth: 1,
    borderColor: '#007AFF',
    borderRadius: 20,
  },
  editProfileButtonText: {
    color: '#007AFF',
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 4,
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  stat: {
    alignItems: 'center',
  },
  statNumber: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
  },
  statLabel: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  favoritesSection: {
    paddingVertical: 16,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
    backgroundColor: '#fafafa',
  },
  favoritesSectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  favoritesSectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: PRIMARY,
  },
  favoritesSectionLoading: {
    paddingVertical: 16,
    alignItems: 'center',
  },
  favoritesEmptyInline: {
    fontSize: 14,
    color: '#666',
    fontStyle: 'italic',
  },
  favoriteRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    borderRadius: 8,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: '#E8E8E8',
    overflow: 'hidden',
  },
  favoriteRowMain: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 12,
  },
  favoriteRowText: {
    flex: 1,
    marginLeft: 10,
  },
  favoriteName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  favoriteCrowd: {
    fontSize: 13,
    color: '#666',
    marginTop: 4,
  },
  favoriteHeart: {
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  menuContainer: {
    paddingVertical: 10,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  menuItemText: {
    flex: 1,
    fontSize: 16,
    color: '#333',
    marginLeft: 16,
  },
  logoutContainer: {
    padding: 20,
  },
  logoutButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderWidth: 1,
    borderColor: '#FF3B30',
    borderRadius: 8,
  },
  logoutButtonText: {
    color: '#FF3B30',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
  versionContainer: {
    alignItems: 'center',
    paddingVertical: 20,
  },
  versionText: {
    fontSize: 12,
    color: '#999',
  },
});
