import { create } from 'zustand';

// Polyfill for crypto.randomUUID (not available in insecure contexts)
const generateUUID = (): string => {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
        return crypto.randomUUID();
    }
    // Fallback for insecure contexts (HTTP)
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = (Math.random() * 16) | 0;
        const v = c === 'x' ? r : (r & 0x3) | 0x8;
        return v.toString(16);
    });
};

export interface Message {
    id: string;
    type: 'user' | 'assistant' | 'system' | 'command' | 'output' | 'error';
    content: string;
    timestamp: Date;
    metadata?: {
        executionId?: string;
        plan?: any;
        commands?: string[];
        riskLevel?: string;
    };
}

export interface Execution {
    id: string;
    prompt: string;
    status: string;
    plan?: any;
    commands?: string[];
    output?: string;
    riskLevel?: string;
    requiresConfirmation?: boolean;
}

interface ChatState {
    messages: Message[];
    currentExecution: Execution | null;
    isProcessing: boolean;
    addMessage: (message: Omit<Message, 'id' | 'timestamp'>) => void;
    clearMessages: () => void;
    setExecution: (execution: Execution | null) => void;
    updateExecution: (updates: Partial<Execution>) => void;
    setProcessing: (processing: boolean) => void;
}

export const useChatStore = create<ChatState>((set) => ({
    messages: [],
    currentExecution: null,
    isProcessing: false,
    addMessage: (message) =>
        set((state) => ({
            messages: [
                ...state.messages,
                {
                    ...message,
                    id: generateUUID(),
                    timestamp: new Date(),
                },
            ],
        })),
    clearMessages: () => set({ messages: [] }),
    setExecution: (currentExecution) => set({ currentExecution }),
    updateExecution: (updates) =>
        set((state) => ({
            currentExecution: state.currentExecution
                ? { ...state.currentExecution, ...updates }
                : null,
        })),
    setProcessing: (isProcessing) => set({ isProcessing }),
}));
