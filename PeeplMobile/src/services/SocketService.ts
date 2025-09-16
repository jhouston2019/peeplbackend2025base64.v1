import io, { Socket } from 'socket.io-client';

const SOCKET_URL = __DEV__ 
  ? 'http://localhost:3000' 
  : 'https://your-production-api.com';

class SocketService {
  private static instance: SocketService;
  private socket: Socket | null = null;
  private isConnected: boolean = false;

  public static getInstance(): SocketService {
    if (!SocketService.instance) {
      SocketService.instance = new SocketService();
    }
    return SocketService.instance;
  }

  async connect(token: string): Promise<void> {
    if (this.socket && this.isConnected) {
      return;
    }

    this.socket = io(SOCKET_URL, {
      auth: {
        token,
      },
      transports: ['websocket'],
    });

    this.socket.on('connect', () => {
      console.log('Socket connected');
      this.isConnected = true;
    });

    this.socket.on('disconnect', () => {
      console.log('Socket disconnected');
      this.isConnected = false;
    });

    this.socket.on('connect_error', (error) => {
      console.error('Socket connection error:', error);
      this.isConnected = false;
    });
  }

  disconnect(): void {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
      this.isConnected = false;
    }
  }

  joinVenue(venueId: string): void {
    if (this.socket && this.isConnected) {
      this.socket.emit('join_venue', venueId);
    }
  }

  leaveVenue(venueId: string): void {
    if (this.socket && this.isConnected) {
      this.socket.emit('leave_venue', venueId);
    }
  }

  onNewPeep(callback: (peep: any) => void): void {
    if (this.socket) {
      this.socket.on('new_peep', callback);
    }
  }

  offNewPeep(callback: (peep: any) => void): void {
    if (this.socket) {
      this.socket.off('new_peep', callback);
    }
  }

  onVenueUpdate(callback: (venue: any) => void): void {
    if (this.socket) {
      this.socket.on('venue_update', callback);
    }
  }

  offVenueUpdate(callback: (venue: any) => void): void {
    if (this.socket) {
      this.socket.off('venue_update', callback);
    }
  }

  getConnectionStatus(): boolean {
    return this.isConnected;
  }
}

export const socketService = SocketService.getInstance();
