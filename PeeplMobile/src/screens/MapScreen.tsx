import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  StyleSheet,
  TouchableOpacity,
  Text,
  Alert,
  Dimensions,
} from 'react-native';
import MapView, { Marker, Region, PROVIDER_GOOGLE } from 'react-native-maps';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { locationService } from '../services/LocationService';
import { Venue } from '../types/Venue';
import { User } from '../types/User';

interface MapScreenProps {
  navigation: any;
  user: User;
}

const { width, height } = Dimensions.get('window');

export default function MapScreen({ navigation, user }: MapScreenProps) {
  const [region, setRegion] = useState<Region>({
    latitude: 37.78825,
    longitude: -122.4324,
    latitudeDelta: 0.0922,
    longitudeDelta: 0.0421,
  });
  const [venues, setVenues] = useState<Venue[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [userLocation, setUserLocation] = useState<{ latitude: number; longitude: number } | null>(null);
  const mapRef = useRef<MapView>(null);

  useEffect(() => {
    initializeMap();
    return () => {
      locationService.stopLocationTracking();
    };
  }, []);

  const initializeMap = async () => {
    try {
      const location = await locationService.getCurrentLocation();
      if (location) {
        setUserLocation(location);
        const newRegion = {
          latitude: location.latitude,
          longitude: location.longitude,
          latitudeDelta: 0.01,
          longitudeDelta: 0.01,
        };
        setRegion(newRegion);
        await loadNearbyVenues(location.latitude, location.longitude);
      }
    } catch (error) {
      console.error('Map initialization error:', error);
      Alert.alert('Error', 'Unable to get your location. Please check your location permissions.');
    } finally {
      setIsLoading(false);
    }
  };

  const loadNearbyVenues = async (latitude: number, longitude: number) => {
    try {
      // This would call your backend API
      // const response = await venueService.getNearbyVenues(latitude, longitude);
      // setVenues(response.data);
      
      // Mock data for now
      const mockVenues: Venue[] = [
        {
          id: '1',
          name: 'Coffee Corner',
          address: '123 Main St',
          latitude: latitude + 0.001,
          longitude: longitude + 0.001,
          category: 'Coffee',
          peepCount: 15,
          averageRating: 4.5,
          totalRatings: 20,
          createdBy: 'user1',
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          isActive: true,
        },
        {
          id: '2',
          name: 'Pizza Palace',
          address: '456 Oak Ave',
          latitude: latitude - 0.002,
          longitude: longitude + 0.003,
          category: 'Restaurant',
          peepCount: 8,
          averageRating: 4.2,
          totalRatings: 12,
          createdBy: 'user2',
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          isActive: true,
        },
      ];
      setVenues(mockVenues);
    } catch (error) {
      console.error('Error loading venues:', error);
    }
  };

  const onRegionChangeComplete = (newRegion: Region) => {
    setRegion(newRegion);
    loadNearbyVenues(newRegion.latitude, newRegion.longitude);
  };

  const centerOnUserLocation = async () => {
    try {
      const location = await locationService.getCurrentLocation();
      if (location && mapRef.current) {
        const newRegion = {
          latitude: location.latitude,
          longitude: location.longitude,
          latitudeDelta: 0.01,
          longitudeDelta: 0.01,
        };
        mapRef.current.animateToRegion(newRegion, 1000);
        setUserLocation(location);
      }
    } catch (error) {
      console.error('Error centering on user location:', error);
    }
  };

  const handleVenuePress = (venue: Venue) => {
    navigation.navigate('Venue', { venue });
  };

  const handleCreatePeep = () => {
    if (userLocation) {
      navigation.navigate('CreatePeep', { 
        location: userLocation,
        venues: venues 
      });
    } else {
      Alert.alert('Location Required', 'Please enable location services to create a peep.');
    }
  };

  const getMarkerColor = (venue: Venue): string => {
    if (venue.averageRating >= 4.5) return '#4CAF50'; // Green
    if (venue.averageRating >= 4.0) return '#FF9800'; // Orange
    if (venue.averageRating >= 3.0) return '#FFC107'; // Yellow
    return '#9E9E9E'; // Gray
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <Text>Loading map...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <MapView
        ref={mapRef}
        style={styles.map}
        provider={PROVIDER_GOOGLE}
        region={region}
        onRegionChangeComplete={onRegionChangeComplete}
        showsUserLocation={true}
        showsMyLocationButton={false}
        showsCompass={true}
        showsScale={true}
      >
        {/* User Location Marker */}
        {userLocation && (
          <Marker
            coordinate={userLocation}
            title="Your Location"
            pinColor="blue"
          />
        )}

        {/* Venue Markers */}
        {venues.map((venue) => (
          <Marker
            key={venue.id}
            coordinate={{
              latitude: venue.latitude,
              longitude: venue.longitude,
            }}
            title={venue.name}
            description={`${venue.category} • ${venue.peepCount} peeps`}
            pinColor={getMarkerColor(venue)}
            onPress={() => handleVenuePress(venue)}
          />
        ))}
      </MapView>

      {/* Floating Action Buttons */}
      <View style={styles.fabContainer}>
        <TouchableOpacity
          style={styles.fab}
          onPress={centerOnUserLocation}
        >
          <Icon name="my-location" size={24} color="#007AFF" />
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.fab, styles.createPeepFab]}
          onPress={handleCreatePeep}
        >
          <Icon name="add" size={24} color="#ffffff" />
        </TouchableOpacity>
      </View>

      {/* Venue List Button */}
      <TouchableOpacity
        style={styles.venueListButton}
        onPress={() => navigation.navigate('Venues')}
      >
        <Icon name="list" size={20} color="#007AFF" />
        <Text style={styles.venueListButtonText}>Venues</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  map: {
    width: width,
    height: height,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  fabContainer: {
    position: 'absolute',
    right: 20,
    bottom: 100,
    alignItems: 'center',
  },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#ffffff',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  createPeepFab: {
    backgroundColor: '#007AFF',
  },
  venueListButton: {
    position: 'absolute',
    left: 20,
    bottom: 100,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 25,
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  venueListButtonText: {
    marginLeft: 8,
    fontSize: 16,
    fontWeight: '600',
    color: '#007AFF',
  },
});
