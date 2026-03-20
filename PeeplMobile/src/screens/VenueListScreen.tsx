import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Image,
  Alert,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../types/Navigation';
import { Venue } from '../types/Venue';
import { locationService } from '../services/LocationService';
import { ApiService } from '../services/ApiService';

interface VenueListScreenProps {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Venues'>;
}

export default function VenueListScreen({ navigation }: VenueListScreenProps) {
  const [venues, setVenues] = useState<Venue[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [userLocation, setUserLocation] = useState<{ latitude: number; longitude: number } | null>(null);

  useEffect(() => {
    loadVenues();
    getCurrentLocation();
  }, []);

  const getCurrentLocation = async () => {
    try {
      const location = await locationService.getCurrentLocation();
      setUserLocation(location);
    } catch (error) {
      console.error('Error getting current location:', error);
    }
  };

  const loadVenues = async () => {
    try {

      if (userLocation) {
        const response: any = await ApiService.getNearbyVenues(
          userLocation.latitude,
          userLocation.longitude,
          5
        );
        setVenues(response.venues || []);
      } else {
        setVenues([]);
      }
    } catch (error) {
      console.error('Error loading venues:', error);
      Alert.alert('Error', 'Failed to load venues. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleVenuePress = (venue: Venue) => {
    navigation.navigate('Venue', { venue });
  };

  const handleCreateVenue = () => {
    Alert.alert('Create Venue', 'Create venue feature coming soon!');
  };

  const renderStars = (rating: number) => {
    const stars = [];
    for (let i = 1; i <= 5; i++) {
      stars.push(
        <Icon
          key={i}
          name={i <= rating ? 'star' : 'star-border'}
          size={12}
          color={i <= rating ? '#FFD700' : '#CCCCCC'}
        />
      );
    }
    return stars;
  };

  const renderVenueItem = ({ item: venue }: { item: Venue }) => (
    <TouchableOpacity
      style={styles.venueCard}
      onPress={() => handleVenuePress(venue)}
    >
      <View style={styles.venueImageContainer}>
        {venue.imageUrl ? (
          <Image source={{ uri: venue.imageUrl }} style={styles.venueImage} />
        ) : (
          <View style={styles.defaultVenueImage}>
            <Icon name="place" size={32} color="#CCCCCC" />
          </View>
        )}
      </View>

      <View style={styles.venueInfo}>
        <Text style={styles.venueName}>{venue.name}</Text>
        <Text style={styles.venueAddress}>{venue.address}</Text>
        <Text style={styles.venueCategory}>{venue.category}</Text>
        
        {venue.description && (
          <Text style={styles.venueDescription} numberOfLines={2}>
            {venue.description}
          </Text>
        )}

        <View style={styles.venueStats}>
          <View style={styles.ratingContainer}>
            <View style={styles.stars}>
              {renderStars(Math.round(venue.averageRating))}
            </View>
            <Text style={styles.ratingText}>
              {venue.averageRating.toFixed(1)} ({venue.totalRatings})
            </Text>
          </View>

          <View style={styles.peepCount}>
            <Icon name="chat-bubble-outline" size={16} color="#007AFF" />
            <Text style={styles.peepCountText}>{venue.peepCount}</Text>
          </View>

          {venue.distance && (
            <View style={styles.distanceContainer}>
              <Icon name="location-on" size={16} color="#666" />
              <Text style={styles.distanceText}>
                {locationService.formatDistance(venue.distance)}
              </Text>
            </View>
          )}
        </View>
      </View>

      <Icon name="chevron-right" size={24} color="#CCCCCC" />
    </TouchableOpacity>
  );

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <Icon name="place" size={64} color="#CCCCCC" />
      <Text style={styles.emptyStateTitle}>No Venues Found</Text>
      <Text style={styles.emptyStateText}>
        Be the first to discover and share venues in your area!
      </Text>
      <TouchableOpacity style={styles.createVenueButton} onPress={handleCreateVenue}>
        <Icon name="add" size={20} color="#ffffff" />
        <Text style={styles.createVenueButtonText}>Create Venue</Text>
      </TouchableOpacity>
    </View>
  );

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.loadingText}>Loading venues...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Venues</Text>
        <TouchableOpacity style={styles.createButton} onPress={handleCreateVenue}>
          <Icon name="add" size={24} color="#007AFF" />
        </TouchableOpacity>
      </View>

      <FlatList
        data={venues}
        renderItem={renderVenueItem}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContainer}
        showsVerticalScrollIndicator={false}
        ListEmptyComponent={renderEmptyState}
      />
    </View>
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
  loadingText: {
    fontSize: 16,
    color: '#666',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  createButton: {
    padding: 8,
  },
  listContainer: {
    padding: 20,
  },
  venueCard: {
    flexDirection: 'row',
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3.84,
    elevation: 5,
  },
  venueImageContainer: {
    marginRight: 16,
  },
  venueImage: {
    width: 80,
    height: 80,
    borderRadius: 8,
  },
  defaultVenueImage: {
    width: 80,
    height: 80,
    borderRadius: 8,
    backgroundColor: '#F0F0F0',
    justifyContent: 'center',
    alignItems: 'center',
  },
  venueInfo: {
    flex: 1,
  },
  venueName: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  venueAddress: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  venueCategory: {
    fontSize: 12,
    color: '#007AFF',
    fontWeight: '600',
    marginBottom: 8,
  },
  venueDescription: {
    fontSize: 14,
    color: '#666',
    lineHeight: 18,
    marginBottom: 8,
  },
  venueStats: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
  },
  ratingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 16,
  },
  stars: {
    flexDirection: 'row',
    marginRight: 4,
  },
  ratingText: {
    fontSize: 12,
    color: '#666',
  },
  peepCount: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 16,
  },
  peepCountText: {
    fontSize: 12,
    color: '#666',
    marginLeft: 4,
  },
  distanceContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  distanceText: {
    fontSize: 12,
    color: '#666',
    marginLeft: 4,
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyStateTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#666',
    marginTop: 16,
    marginBottom: 8,
  },
  emptyStateText: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
    lineHeight: 20,
    marginBottom: 24,
  },
  createVenueButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#007AFF',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 25,
  },
  createVenueButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
});
