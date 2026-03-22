import { authService, API_BASE_URL } from './AuthService';
import type { CreatePeepData } from '../types/Peep';

async function request<T>(method: string, path: string, body?: object): Promise<T> {
  const token = await authService.getIdToken();
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }
  return response.json();
}

export const ApiService = {
  getNearbyVenues: (lat: number, lng: number, radius: number) =>
    request('POST', '/venues/nearby', { lat, lng, radius }),
  getVenue: (venueId: string) => request('GET', `/venues/${venueId}`, undefined),
  getFeed: () => request('GET', '/feed', undefined),
  createPeep: async (data: CreatePeepData) => {
    const token = await authService.getIdToken();
    const formData = new FormData();

    formData.append('venueId', data.venueId);
    formData.append('description', data.description);
    formData.append('crowdSize', String(data.crowdSize));
    formData.append('mfRatio', String(data.mfRatio));
    formData.append('akRatio', String(data.akRatio));
    data.ageRanges.forEach((a) => formData.append('ageRanges', a));
    data.vibe.forEach((v) => formData.append('vibe', v));
    formData.append('crowdTrend', data.crowdTrend);
    if (data.latitude !== undefined && data.latitude !== null) {
      formData.append('latitude', String(data.latitude));
    }
    if (data.longitude !== undefined && data.longitude !== null) {
      formData.append('longitude', String(data.longitude));
    }

    if (data.image?.uri) {
      const uri = data.image.uri;
      const filename = uri.split('/').pop() || 'photo.jpg';
      const match = /\.(\w+)$/.exec(filename);
      const type = match ? `image/${match[1]}` : 'image/jpeg';
      formData.append('photo', {
        uri,
        name: filename,
        type,
      } as any);
    }

    const response = await fetch(`${API_BASE_URL}/peeps`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
      },
      body: formData,
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }
    return response.json();
  },
  getUserProfile: (userId: string) => request('GET', `/users/${userId}`, undefined),
  updateUserProfile: (data: object) => request('PUT', '/users/profile', data),
  getVenuePeeps: (venueId: string) => request('GET', `/peeps/venue/${venueId}`, undefined),
};
