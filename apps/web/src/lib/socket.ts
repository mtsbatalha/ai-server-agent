import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '@/stores/auth-store';

let socket: Socket | null = null;

export const getSocket = (): Socket => {
    if (!socket) {
        const token = useAuthStore.getState().token;

        socket = io('http://localhost:3001/chat', {
            auth: { token },
            transports: ['websocket'],
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
