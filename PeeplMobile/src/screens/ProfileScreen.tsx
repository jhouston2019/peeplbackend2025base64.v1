import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Image,
  Alert,
  Modal,
  FlatList,
  ActivityIndicator,
  RefreshControl,
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

interface ProfileScreenProps {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Profile'>;
}

export default function ProfileScreen({ navigation }: ProfileScreenProps) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [favoritesModalVisible, setFavoritesModalVisible] = useState(false);
  const [favorites, setFavorites] = useState<Venue[]>([]);
  const [favoritesLoading, setFavoritesLoading] = useState(false);
  const [favoritesRefreshing, setFavoritesRefreshing] = useState(false);

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

  const getAuthHeaders = async () => {
    const token = await auth().currentUser?.getIdToken();
    return {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    };
  };

  const loadFavorites = useCallback(async (isRefresh = false) => {
    if (isRefresh) setFavoritesRefreshing(true);
    else setFavoritesLoading(true);
    try {
      const headers = await getAuthHeaders();
      const res = await axios.get<{ favorites: Venue[] }>(`${API_BASE_URL}/users/favorites`, { headers });
      setFavorites(res.data.favorites || []);
    } catch (error) {
      console.error('Error loading favorites:', error);
      Alert.alert('Error', 'Could not load favorite venues.');
    } finally {
      setFavoritesLoading(false);
      setFavoritesRefreshing(false);
    }
  }, []);

  const handleRemoveFavorite = async (venueId: string) => {
    try {
      const headers = await getAuthHeaders();
      await axios.delete(`${API_BASE_URL}/users/favorites/${venueId}`, { headers });
      setFavorites((prev) => prev.filter((v) => v.id !== venueId));
    } catch (error) {
      console.error('Error removing favorite:', error);
      Alert.alert('Error', 'Could not remove this favorite.');
    }
  };

  const handleFavorites = () => {
    setFavoritesModalVisible(true);
    loadFavorites();
  };

  const onFavoritesRefresh = () => {
    loadFavorites(true);
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
    <>
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

      {/* Menu Items */}
      <View style={styles.menuContainer}>
        <TouchableOpacity style={styles.menuItem} onPress={handleMyPeeps}>
          <Icon name="chat-bubble-outline" size={24} color="#007AFF" />
          <Text style={styles.menuItemText}>My Peeps</Text>
          <Icon name="chevron-right" size={24} color="#CCCCCC" />
        </TouchableOpacity>

        <TouchableOpacity style={styles.menuItem} onPress={handleFavorites}>
          <Icon name="favorite-border" size={24} color="#007AFF" />
          <Text style={styles.menuItemText}>Favorites</Text>
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

    <Modal
      visible={favoritesModalVisible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={() => setFavoritesModalVisible(false)}
    >
      <View style={styles.favoritesModal}>
        <View style={styles.favoritesHeader}>
          <Text style={styles.favoritesTitle}>Favorite venues</Text>
          <TouchableOpacity
            onPress={() => setFavoritesModalVisible(false)}
            accessibilityRole="button"
            accessibilityLabel="Close favorites"
          >
            <Icon name="close" size={28} color="#FFFFFF" />
          </TouchableOpacity>
        </View>
        {favoritesLoading && favorites.length === 0 ? (
          <View style={styles.favoritesCentered}>
            <ActivityIndicator size="large" color={ACCENT} />
          </View>
        ) : (
          <FlatList
            data={favorites}
            keyExtractor={(item) => item.id}
            refreshControl={
              <RefreshControl refreshing={favoritesRefreshing} onRefresh={onFavoritesRefresh} tintColor={ACCENT} />
            }
            ListEmptyComponent={
              <View style={styles.favoritesEmpty}>
                <Icon name="favorite-border" size={48} color={ACCENT} />
                <Text style={styles.favoritesEmptyText}>No favorites yet</Text>
                <Text style={styles.favoritesEmptyHint}>Save venues from a venue page to see them here.</Text>
              </View>
            }
            renderItem={({ item }) => (
              <View style={styles.favoriteRow}>
                <TouchableOpacity
                  style={styles.favoriteRowMain}
                  onPress={() => {
                    setFavoritesModalVisible(false);
                    navigation.navigate('Venue', { venue: item });
                  }}
                >
                  <Icon name="place" size={22} color={PRIMARY} />
                  <View style={styles.favoriteRowText}>
                    <Text style={styles.favoriteName}>{item.name}</Text>
                    {item.category ? (
                      <Text style={styles.favoriteMeta}>{item.category}</Text>
                    ) : null}
                  </View>
                  <Icon name="chevron-right" size={24} color="#CCCCCC" />
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.favoriteRemove}
                  onPress={() => handleRemoveFavorite(item.id)}
                  accessibilityRole="button"
                  accessibilityLabel={`Remove ${item.name} from favorites`}
                >
                  <Icon name="delete-outline" size={24} color="#FF3B30" />
                </TouchableOpacity>
              </View>
            )}
            contentContainerStyle={favorites.length === 0 ? styles.favoritesListEmpty : undefined}
          />
        )}
      </View>
    </Modal>
    </>
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
  favoritesModal: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  favoritesHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 16,
    backgroundColor: PRIMARY,
  },
  favoritesTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  favoritesCentered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  favoritesListEmpty: {
    flexGrow: 1,
    justifyContent: 'center',
  },
  favoritesEmpty: {
    alignItems: 'center',
    paddingHorizontal: 32,
    paddingVertical: 48,
  },
  favoritesEmptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginTop: 12,
  },
  favoritesEmptyHint: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    marginTop: 8,
  },
  favoriteRow: {
    flexDirection: 'row',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  favoriteRowMain: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingLeft: 16,
    paddingRight: 8,
  },
  favoriteRowText: {
    flex: 1,
    marginLeft: 12,
  },
  favoriteName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  favoriteMeta: {
    fontSize: 13,
    color: '#666',
    marginTop: 2,
  },
  favoriteRemove: {
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
});
