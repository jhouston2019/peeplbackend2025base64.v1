import { authService } from './AuthService';

const BASE_URL = __DEV__ 
  ? 'http://localhost:3000' 
  : 'https://your-production-api.com';

async function request<T>(method: string, path: string, body?: object): Promise<T> {
  const token = await authService.getIdToken();
  const response = await fetch(`${BASE_URL}${path}`, {
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
  getVenue: (venueId: string) =>
    request('GET', `/venues/${venueId}`, undefined),
  createPeep: (data: object) =>
    request('POST', '/peeps', data),
  getFeed: () =>
    request('GET', '/feed', undefined),
  getUserProfile: (userId: string) =>
    request('GET', `/users/${userId}`, undefined),
  updateUserProfile: (data: object) =>
    request('PUT', '/users/profile', data),
  getVenuePeeps: (venueId: string) =>
    request('GET', `/peeps/venue/${venueId}`, undefined),
};
