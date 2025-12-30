import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '@/stores/auth-store';

let socket: Socket | null = null;

// Get WebSocket URL - must connect directly to API (not via Next.js proxy)
const getWsUrl = () => {
    if (typeof window !== 'undefined') {
        // Use explicit WebSocket URL if provided
        const wsUrl = process.env.NEXT_PUBLIC_WS_URL;
        if (wsUrl) {
            return wsUrl;
        }
        // Fallback: construct from current location (assumes API on same host, different port)
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.hostname;
        // Default to port 3001 for API if not specified
        const apiPort = process.env.NEXT_PUBLIC_API_PORT || '3001';
        return `${protocol}//${host}:${apiPort}`;
    }
    return process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';
};

export const getSocket = (): Socket => {
    if (!socket) {
        const token = useAuthStore.getState().token;
        const wsUrl = getWsUrl();

        socket = io(`${wsUrl}/chat`, {
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
