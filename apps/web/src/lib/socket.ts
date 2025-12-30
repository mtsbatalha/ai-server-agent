import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '@/stores/auth-store';

let socket: Socket | null = null;

// Get API URL from environment or use relative path for same-origin
const getApiUrl = () => {
    // In browser, use relative URL which will be proxied by Next.js
    if (typeof window !== 'undefined') {
        return '';  // Empty string = same origin, will use Next.js rewrite
    }
    return process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';
};

export const getSocket = (): Socket => {
    if (!socket) {
        const token = useAuthStore.getState().token;
        const apiUrl = getApiUrl();

        socket = io(`${apiUrl}/chat`, {
            auth: { token },
            transports: ['websocket', 'polling'],
            autoConnect: false,
        });
    }
    return socket;
};

export const connectSocket = (): Promise<void> => {
    return new Promise((resolve, reject) => {
        const s = getSocket();

        if (s.connected) {
            resolve();
            return;
        }

        s.connect();

        s.on('connect', () => {
            console.log('Socket connected');
            resolve();
        });

        s.on('connect_error', (error) => {
            console.error('Socket connection error:', error);
            reject(error);
        });
    });
};

export const disconnectSocket = () => {
    if (socket) {
        socket.disconnect();
        socket = null;
    }
};

export const resetSocket = () => {
    disconnectSocket();
    socket = null;
};
