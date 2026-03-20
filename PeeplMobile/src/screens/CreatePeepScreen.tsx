import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  Image,
  Alert,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { launchImageLibrary, ImagePickerResponse, MediaType } from 'react-native-image-picker';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '../types/Navigation';
import { Venue } from '../types/Venue';
import { CreatePeepData } from '../types/Peep';

interface CreatePeepScreenProps {
  route: RouteProp<RootStackParamList, 'CreatePeep'>;
  navigation: NativeStackNavigationProp<RootStackParamList, 'CreatePeep'>;
}

export default function CreatePeepScreen({ route, navigation }: CreatePeepScreenProps) {
  const { venue, location, venues = [] } = route.params;
  const [selectedVenue, setSelectedVenue] = useState<Venue | null>(venue || null);
  const [description, setDescription] = useState('');
  const [rating, setRating] = useState(0);
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSelectImage = () => {
    const options = {
      mediaType: 'photo' as MediaType,
      quality: 0.8,
      maxWidth: 1000,
      maxHeight: 1000,
    };

    launchImageLibrary(options, (response: ImagePickerResponse) => {
      if (response.didCancel || response.errorMessage) {
        return;
      }

      if (response.assets && response.assets[0]) {
        setSelectedImage(response.assets[0].uri || null);
      }
    });
  };

  const handleRemoveImage = () => {
    setSelectedImage(null);
  };

  const handleRatingPress = (selectedRating: number) => {
    setRating(selectedRating);
  };

  const handleSubmit = async () => {
    if (!selectedVenue) {
      Alert.alert('Error', 'Please select a venue');
      return;
    }

    if (!description.trim()) {
      Alert.alert('Error', 'Please enter a description');
      return;
    }

    setIsSubmitting(true);
    try {
      const peepData: CreatePeepData = {
        venueId: selectedVenue.id,
        description: description.trim(),
        rating: rating > 0 ? rating : undefined,
        latitude: location?.latitude,
        longitude: location?.longitude,
        image: selectedImage ? {
          uri: selectedImage,
          type: 'image/jpeg',
          name: 'peep_image.jpg',
        } : undefined,
      };

      // This would call your backend API
      // await peepService.createPeep(peepData);
      
      Alert.alert(
        'Success',
        'Your peep has been created!',
        [
          {
            text: 'OK',
            onPress: () => navigation.goBack(),
          },
        ]
      );
    } catch (error) {
      console.error('Error creating peep:', error);
      Alert.alert('Error', 'Failed to create peep. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const renderStars = () => {
    const stars = [];
    for (let i = 1; i <= 5; i++) {
      stars.push(
        <TouchableOpacity
          key={i}
          onPress={() => handleRatingPress(i)}
          style={styles.starButton}
        >
          <Icon
            name={i <= rating ? 'star' : 'star-border'}
            size={32}
            color={i <= rating ? '#FFD700' : '#CCCCCC'}
          />
        </TouchableOpacity>
      );
    }
    return stars;
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        {/* Venue Selection */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Select Venue</Text>
          {selectedVenue ? (
            <View style={styles.selectedVenue}>
              <View style={styles.venueInfo}>
                <Text style={styles.venueName}>{selectedVenue.name}</Text>
                <Text style={styles.venueAddress}>{selectedVenue.address}</Text>
                <Text style={styles.venueCategory}>{selectedVenue.category}</Text>
              </View>
              <TouchableOpacity
                style={styles.changeVenueButton}
                onPress={() => setSelectedVenue(null)}
              >
                <Text style={styles.changeVenueButtonText}>Change</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.venueList}>
              {venues.map((v) => (
                <TouchableOpacity
                  key={v.id}
                  style={styles.venueOption}
                  onPress={() => setSelectedVenue(v)}
                >
                  <View style={styles.venueOptionInfo}>
                    <Text style={styles.venueOptionName}>{v.name}</Text>
                    <Text style={styles.venueOptionAddress}>{v.address}</Text>
                    <Text style={styles.venueOptionCategory}>{v.category}</Text>
                  </View>
                  <Icon name="chevron-right" size={24} color="#CCCCCC" />
                </TouchableOpacity>
              ))}
            </View>
          )}
        </View>

        {/* Rating */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Rating (Optional)</Text>
          <View style={styles.ratingContainer}>
            {renderStars()}
          </View>
        </View>

        {/* Description */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Description</Text>
          <TextInput
            style={styles.descriptionInput}
            placeholder="Share your experience..."
            placeholderTextColor="#999"
            value={description}
            onChangeText={setDescription}
            multiline
            numberOfLines={4}
            maxLength={500}
          />
          <Text style={styles.characterCount}>{description.length}/500</Text>
        </View>

        {/* Image */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Photo (Optional)</Text>
          {selectedImage ? (
            <View style={styles.imageContainer}>
              <Image source={{ uri: selectedImage }} style={styles.selectedImage} />
              <TouchableOpacity style={styles.removeImageButton} onPress={handleRemoveImage}>
                <Icon name="close" size={20} color="#ffffff" />
              </TouchableOpacity>
            </View>
          ) : (
            <TouchableOpacity style={styles.addImageButton} onPress={handleSelectImage}>
              <Icon name="camera-alt" size={32} color="#007AFF" />
              <Text style={styles.addImageButtonText}>Add Photo</Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Location Info */}
        {location && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Location</Text>
            <View style={styles.locationInfo}>
              <Icon name="location-on" size={20} color="#007AFF" />
              <Text style={styles.locationText}>
                {location.latitude.toFixed(6)}, {location.longitude.toFixed(6)}
              </Text>
            </View>
          </View>
        )}
      </ScrollView>

      {/* Submit Button */}
      <View style={styles.submitContainer}>
        <TouchableOpacity
          style={[styles.submitButton, isSubmitting && styles.submitButtonDisabled]}
          onPress={handleSubmit}
          disabled={isSubmitting}
        >
          <Text style={styles.submitButtonText}>
            {isSubmitting ? 'Creating Peep...' : 'Create Peep'}
          </Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  scrollView: {
    flex: 1,
  },
  section: {
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  selectedVenue: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F8F9FA',
    padding: 16,
    borderRadius: 12,
  },
  venueInfo: {
    flex: 1,
  },
  venueName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  venueAddress: {
    fontSize: 14,
    color: '#666',
    marginTop: 2,
  },
  venueCategory: {
    fontSize: 12,
    color: '#007AFF',
    marginTop: 2,
  },
  changeVenueButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: '#007AFF',
    borderRadius: 6,
  },
  changeVenueButtonText: {
    color: '#007AFF',
    fontSize: 14,
    fontWeight: '600',
  },
  venueList: {
    maxHeight: 200,
  },
  venueOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
    marginBottom: 8,
  },
  venueOptionInfo: {
    flex: 1,
  },
  venueOptionName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  venueOptionAddress: {
    fontSize: 14,
    color: '#666',
    marginTop: 2,
  },
  venueOptionCategory: {
    fontSize: 12,
    color: '#007AFF',
    marginTop: 2,
  },
  ratingContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
  },
  starButton: {
    padding: 4,
  },
  descriptionInput: {
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    color: '#333',
    textAlignVertical: 'top',
    minHeight: 100,
  },
  characterCount: {
    fontSize: 12,
    color: '#999',
    textAlign: 'right',
    marginTop: 4,
  },
  imageContainer: {
    position: 'relative',
  },
  selectedImage: {
    width: '100%',
    height: 200,
    borderRadius: 12,
  },
  removeImageButton: {
    position: 'absolute',
    top: 8,
    right: 8,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    borderRadius: 15,
    width: 30,
    height: 30,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addImageButton: {
    borderWidth: 2,
    borderColor: '#007AFF',
    borderStyle: 'dashed',
    borderRadius: 12,
    padding: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addImageButtonText: {
    color: '#007AFF',
    fontSize: 16,
    fontWeight: '600',
    marginTop: 8,
  },
  locationInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F8F9FA',
    padding: 12,
    borderRadius: 8,
  },
  locationText: {
    fontSize: 14,
    color: '#666',
    marginLeft: 8,
  },
  submitContainer: {
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  submitButton: {
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  submitButtonDisabled: {
    backgroundColor: '#B0B0B0',
  },
  submitButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
});
