import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Image,
  Alert,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { Venue } from '../types/Venue';
import { Peep } from '../types/Peep';

interface VenueScreenProps {
  route: {
    params: {
      venue: Venue;
    };
  };
  navigation: any;
}

export default function VenueScreen({ route, navigation }: VenueScreenProps) {
  const { venue } = route.params;
  const [peeps, setPeeps] = useState<Peep[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadVenuePeeps();
  }, []);

  const loadVenuePeeps = async () => {
    try {
      // This would call your backend API
      // const response = await peepService.getVenuePeeps(venue.id);
      // setPeeps(response.data);
      
      // Mock data for now
      const mockPeeps: Peep[] = [
        {
          id: '1',
          venueId: venue.id,
          userId: 'user1',
          description: 'Great coffee and friendly staff!',
          rating: 5,
          latitude: venue.latitude,
          longitude: venue.longitude,
          imageUrl: null,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          isActive: true,
          likeCount: 8,
          commentCount: 2,
          user: {
            username: 'coffeelover',
            firstName: 'John',
            lastName: 'Doe',
            profileImageUrl: null,
          },
          venue: {
            name: venue.name,
            address: venue.address,
          },
        },
        {
          id: '2',
          venueId: venue.id,
          userId: 'user2',
          description: 'Perfect atmosphere for working remotely',
          rating: 4,
          latitude: venue.latitude,
          longitude: venue.longitude,
          imageUrl: null,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          isActive: true,
          likeCount: 5,
          commentCount: 1,
          user: {
            username: 'remoteworker',
            firstName: 'Jane',
            lastName: 'Smith',
            profileImageUrl: null,
          },
          venue: {
            name: venue.name,
            address: venue.address,
          },
        },
      ];
      setPeeps(mockPeeps);
    } catch (error) {
      console.error('Error loading venue peeps:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreatePeep = () => {
    navigation.navigate('CreatePeep', { venue });
  };

  const renderStars = (rating: number) => {
    const stars = [];
    for (let i = 1; i <= 5; i++) {
      stars.push(
        <Icon
          key={i}
          name={i <= rating ? 'star' : 'star-border'}
          size={16}
          color={i <= rating ? '#FFD700' : '#CCCCCC'}
        />
      );
    }
    return stars;
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString();
  };

  return (
    <ScrollView style={styles.container}>
      {/* Venue Header */}
      <View style={styles.header}>
        {venue.imageUrl && (
          <Image source={{ uri: venue.imageUrl }} style={styles.venueImage} />
        )}
        <View style={styles.venueInfo}>
          <Text style={styles.venueName}>{venue.name}</Text>
          <Text style={styles.venueAddress}>{venue.address}</Text>
          <Text style={styles.venueCategory}>{venue.category}</Text>
          
          {venue.description && (
            <Text style={styles.venueDescription}>{venue.description}</Text>
          )}

          {/* Rating */}
          <View style={styles.ratingContainer}>
            <View style={styles.stars}>
              {renderStars(Math.round(venue.averageRating))}
            </View>
            <Text style={styles.ratingText}>
              {venue.averageRating.toFixed(1)} ({venue.totalRatings} reviews)
            </Text>
          </View>

          {/* Stats */}
          <View style={styles.statsContainer}>
            <View style={styles.stat}>
              <Icon name="chat-bubble-outline" size={20} color="#007AFF" />
              <Text style={styles.statText}>{venue.peepCount} peeps</Text>
            </View>
          </View>
        </View>
      </View>

      {/* Action Buttons */}
      <View style={styles.actionButtons}>
        <TouchableOpacity style={styles.createPeepButton} onPress={handleCreatePeep}>
          <Icon name="add" size={20} color="#ffffff" />
          <Text style={styles.createPeepButtonText}>Create Peep</Text>
        </TouchableOpacity>
      </View>

      {/* Peeps Section */}
      <View style={styles.peepsSection}>
        <Text style={styles.sectionTitle}>Recent Peeps</Text>
        
        {isLoading ? (
          <Text style={styles.loadingText}>Loading peeps...</Text>
        ) : peeps.length === 0 ? (
          <View style={styles.emptyState}>
            <Icon name="chat-bubble-outline" size={48} color="#CCCCCC" />
            <Text style={styles.emptyStateText}>No peeps yet</Text>
            <Text style={styles.emptyStateSubtext}>Be the first to share your experience!</Text>
          </View>
        ) : (
          peeps.map((peep) => (
            <View key={peep.id} style={styles.peepCard}>
              <View style={styles.peepHeader}>
                <View style={styles.userInfo}>
                  <Text style={styles.userName}>
                    {peep.user?.firstName} {peep.user?.lastName}
                  </Text>
                  <Text style={styles.userHandle}>@{peep.user?.username}</Text>
                </View>
                <Text style={styles.peepDate}>{formatDate(peep.createdAt)}</Text>
              </View>

              <Text style={styles.peepDescription}>{peep.description}</Text>

              {peep.rating && (
                <View style={styles.peepRating}>
                  {renderStars(peep.rating)}
                </View>
              )}

              {peep.imageUrl && (
                <Image source={{ uri: peep.imageUrl }} style={styles.peepImage} />
              )}

              <View style={styles.peepActions}>
                <TouchableOpacity style={styles.peepAction}>
                  <Icon name="favorite-border" size={20} color="#666" />
                  <Text style={styles.peepActionText}>{peep.likeCount}</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.peepAction}>
                  <Icon name="chat-bubble-outline" size={20} color="#666" />
                  <Text style={styles.peepActionText}>{peep.commentCount}</Text>
                </TouchableOpacity>
              </View>
            </View>
          ))
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  header: {
    backgroundColor: '#f8f9fa',
    padding: 20,
  },
  venueImage: {
    width: '100%',
    height: 200,
    borderRadius: 12,
    marginBottom: 16,
  },
  venueInfo: {
    flex: 1,
  },
  venueName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  venueAddress: {
    fontSize: 16,
    color: '#666',
    marginBottom: 4,
  },
  venueCategory: {
    fontSize: 14,
    color: '#007AFF',
    fontWeight: '600',
    marginBottom: 8,
  },
  venueDescription: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
    marginBottom: 12,
  },
  ratingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  stars: {
    flexDirection: 'row',
    marginRight: 8,
  },
  ratingText: {
    fontSize: 14,
    color: '#666',
  },
  statsContainer: {
    flexDirection: 'row',
  },
  stat: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 20,
  },
  statText: {
    fontSize: 14,
    color: '#666',
    marginLeft: 4,
  },
  actionButtons: {
    padding: 20,
  },
  createPeepButton: {
    backgroundColor: '#007AFF',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 25,
  },
  createPeepButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
  peepsSection: {
    padding: 20,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 16,
  },
  loadingText: {
    textAlign: 'center',
    color: '#666',
    fontSize: 16,
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyStateText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#666',
    marginTop: 12,
  },
  emptyStateSubtext: {
    fontSize: 14,
    color: '#999',
    marginTop: 4,
  },
  peepCard: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  peepHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  userInfo: {
    flex: 1,
  },
  userName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  userHandle: {
    fontSize: 14,
    color: '#666',
  },
  peepDate: {
    fontSize: 12,
    color: '#999',
  },
  peepDescription: {
    fontSize: 14,
    color: '#333',
    lineHeight: 20,
    marginBottom: 8,
  },
  peepRating: {
    flexDirection: 'row',
    marginBottom: 8,
  },
  peepImage: {
    width: '100%',
    height: 200,
    borderRadius: 8,
    marginBottom: 12,
  },
  peepActions: {
    flexDirection: 'row',
    borderTopWidth: 1,
    borderTopColor: '#F0F0F0',
    paddingTop: 12,
  },
  peepAction: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 20,
  },
  peepActionText: {
    fontSize: 14,
    color: '#666',
    marginLeft: 4,
  },
});
