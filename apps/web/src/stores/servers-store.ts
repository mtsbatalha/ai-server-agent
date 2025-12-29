import { create } from 'zustand';

export interface Server {
    id: string;
    name: string;
    description: string | null;
    host: string;
    port: number;
    username: string;
    authType: 'PASSWORD' | 'KEY';
    status: 'CONNECTED' | 'DISCONNECTED' | 'ERROR';
    lastConnection: string | null;
    tags: string[];
    createdAt: string;
}

interface ServersState {
    servers: Server[];
    selectedServer: Server | null;
    isLoading: boolean;
    setServers: (servers: Server[]) => void;
    addServer: (server: Server) => void;
    updateServer: (id: string, updates: Partial<Server>) => void;
    removeServer: (id: string) => void;
    selectServer: (server: Server | null) => void;
    setLoading: (loading: boolean) => void;
}

export const useServersStore = create<ServersState>((set) => ({
    servers: [],
    selectedServer: null,
    isLoading: false,
    setServers: (servers) => set({ servers }),
    addServer: (server) =>
        set((state) => ({ servers: [server, ...state.servers] })),
    updateServer: (id, updates) =>
        set((state) => ({
            servers: state.servers.map((s) =>
                s.id === id ? { ...s, ...updates } : s
            ),
            selectedServer:
                state.selectedServer?.id === id
                    ? { ...state.selectedServer, ...updates }
                    : state.selectedServer,
        })),
    removeServer: (id) =>
        set((state) => ({
            servers: state.servers.filter((s) => s.id !== id),
            selectedServer:
                state.selectedServer?.id === id ? null : state.selectedServer,
        })),
    selectServer: (server) => set({ selectedServer: server }),
    setLoading: (isLoading) => set({ isLoading }),
}));
