'use client';

import { useEffect, useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import {
    Terminal,
    Server,
    Plus,
    Send,
    LogOut,
    Loader2,
    CheckCircle,
    XCircle,
    AlertTriangle,
    Play,
    X,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useToast } from '@/hooks/use-toast';
import { useAuthStore } from '@/stores/auth-store';
import { useServersStore, Server as ServerType } from '@/stores/servers-store';
import { useChatStore, Message } from '@/stores/chat-store';
import { serversApi } from '@/lib/api';
import { getSocket, connectSocket, disconnectSocket } from '@/lib/socket';

export default function DashboardPage() {
    const router = useRouter();
    const { toast } = useToast();
    const { user, isAuthenticated, hasHydrated, logout } = useAuthStore();
    const { servers, selectedServer, setServers, selectServer, setLoading } = useServersStore();
    const { messages, currentExecution, isProcessing, addMessage, setExecution, updateExecution, setProcessing, clearMessages } = useChatStore();

    const [prompt, setPrompt] = useState('');
    const [showAddServer, setShowAddServer] = useState(false);
    const messagesEndRef = useRef<HTMLDivElement>(null);

    // Auth check - wait for hydration before checking
    useEffect(() => {
        if (hasHydrated && !isAuthenticated) {
            router.push('/login');
        }
    }, [hasHydrated, isAuthenticated, router]);

    // Load servers
    useEffect(() => {
        const loadServers = async () => {
            try {
                setLoading(true);
                const response = await serversApi.getAll();
                setServers(response.data);
            } catch (error) {
                console.error('Failed to load servers:', error);
            } finally {
                setLoading(false);
            }
        };

        if (isAuthenticated) {
            loadServers();
        }
    }, [isAuthenticated, setServers, setLoading]);

    // Socket connection
    useEffect(() => {
        if (!isAuthenticated) return;

        const setupSocket = async () => {
            try {
                await connectSocket();
                const socket = getSocket();

                socket.on('status', (data) => {
                    updateExecution({ status: data.status });
                    addMessage({
                        type: 'system',
                        content: `📊 ${data.message}`,
                    });
                });

                socket.on('plan', (data) => {
                    updateExecution({ plan: data.plan });
                    addMessage({
                        type: 'assistant',
                        content: `📋 **Plano de Execução**\n\n**Objetivo:** ${data.plan.objective}\n\n**Passos:**\n${data.plan.steps.map((s: string, i: number) => `${i + 1}. ${s}`).join('\n')}\n\n**Riscos:** ${data.plan.risks.join(', ') || 'Nenhum identificado'}\n\n**Tempo estimado:** ${data.plan.estimatedTime}`,
                    });
                });

                socket.on('commands', (data) => {
                    updateExecution({
                        commands: data.commands,
                        riskLevel: data.riskLevel,
                        requiresConfirmation: data.requiresConfirmation,
                    });
                    addMessage({
                        type: 'assistant',
                        content: `💻 **Comandos a executar:**\n\n${data.commands.map((c: string) => `\`\`\`bash\n${c}\n\`\`\``).join('\n')}\n\n${data.explanation}\n\n⚠️ **Nível de risco:** ${data.riskLevel}${data.warnings.length > 0 ? `\n\n**Avisos:** ${data.warnings.join(', ')}` : ''}`,
                        metadata: { commands: data.commands, riskLevel: data.riskLevel },
                    });

                    if (data.requiresConfirmation) {
                        setProcessing(false);
                    }
                });

                socket.on('output', (data) => {
                    addMessage({
                        type: data.type === 'stderr' ? 'error' : 'output',
                        content: data.content,
                    });
                });

                socket.on('blocked', (data) => {
                    addMessage({
                        type: 'error',
                        content: `🚫 **Execução bloqueada!**\n\nComandos perigosos detectados:\n${data.blockedCommands.map((c: string) => `- \`${c}\``).join('\n')}\n\n${data.reason}`,
                    });
                    setProcessing(false);
                });

                socket.on('complete', (data) => {
                    addMessage({
                        type: 'assistant',
                        content: `${data.success ? '✅' : '❌'} **Execução ${data.success ? 'concluída!' : 'falhou'}**\n\n${data.analysis.summary}\n\n${data.analysis.details}${data.analysis.nextSteps.length > 0 ? `\n\n**Próximos passos sugeridos:**\n${data.analysis.nextSteps.map((s: string) => `- ${s}`).join('\n')}` : ''}`,
                    });
                    setExecution(null);
                    setProcessing(false);
                });

                socket.on('error', (data) => {
                    addMessage({
                        type: 'error',
                        content: `❌ Erro: ${data.message}`,
                    });
                    setProcessing(false);
                });

            } catch (error) {
                console.error('Socket connection failed:', error);
            }
        };

        setupSocket();

        return () => {
            disconnectSocket();
        };
    }, [isAuthenticated, addMessage, updateExecution, setExecution, setProcessing]);

    // Auto-scroll messages
    useEffect(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [messages]);

    const handleSendPrompt = () => {
        if (!prompt.trim() || !selectedServer || isProcessing) return;

        const socket = getSocket();

        addMessage({
            type: 'user',
            content: prompt,
        });

        setExecution({
            id: '',
            prompt,
            status: 'PLANNING',
        });
        setProcessing(true);

        socket.emit('execute', {
            serverId: selectedServer.id,
            prompt: prompt.trim(),
            dryRun: false,
        });

        setPrompt('');
    };

    const handleConfirm = () => {
        if (!currentExecution) return;

        const socket = getSocket();
        socket.emit('confirm', { executionId: currentExecution.id });
        setProcessing(true);
    };

    const handleCancel = () => {
        if (!currentExecution) return;

        const socket = getSocket();
        socket.emit('cancel', { executionId: currentExecution.id });
        setExecution(null);
        addMessage({
            type: 'system',
            content: '🚫 Execução cancelada pelo usuário.',
        });
    };

    const handleLogout = () => {
        logout();
        router.push('/');
    };

    const getStatusColor = (status: ServerType['status']) => {
        switch (status) {
            case 'CONNECTED': return 'status-connected';
            case 'ERROR': return 'status-error';
            default: return 'status-disconnected';
        }
    };

    if (!isAuthenticated) {
        return null;
    }

    return (
        <div className="min-h-screen bg-background flex">
            {/* Sidebar */}
            <aside className="w-64 border-r border-border flex flex-col">
                <div className="p-4 border-b border-border">
                    <div className="flex items-center gap-2">
                        <Terminal className="h-6 w-6 text-primary" />
                        <span className="font-bold gradient-text">AI Server Admin</span>
                    </div>
                </div>

                <div className="p-4 border-b border-border">
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-sm font-medium">Servidores</span>
                        <Button size="icon" variant="ghost" onClick={() => setShowAddServer(true)}>
                            <Plus className="h-4 w-4" />
                        </Button>
                    </div>

                    <div className="space-y-2">
                        {servers.map((server) => (
                            <button
                                key={server.id}
                                onClick={() => {
                                    selectServer(server);
                                    clearMessages();
                                }}
                                className={`w-full text-left p-2 rounded-lg transition-colors ${selectedServer?.id === server.id
                                    ? 'bg-primary/20 border border-primary/50'
                                    : 'hover:bg-secondary'
                                    }`}
                            >
                                <div className="flex items-center gap-2">
                                    <Server className="h-4 w-4" />
                                    <span className="text-sm font-medium truncate">{server.name}</span>
                                </div>
                                <div className="flex items-center gap-2 mt-1">
                                    <span className={`text-xs px-2 py-0.5 rounded-full border ${getStatusColor(server.status)}`}>
                                        {server.status}
                                    </span>
                                </div>
                            </button>
                        ))}

                        {servers.length === 0 && (
                            <p className="text-sm text-muted-foreground text-center py-4">
                                Nenhum servidor cadastrado
                            </p>
                        )}
                    </div>
                </div>

                <div className="mt-auto p-4 border-t border-border">
                    <div className="flex items-center gap-2 mb-4">
                        <div className="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center">
                            <span className="text-sm font-medium">{user?.name?.[0]?.toUpperCase()}</span>
                        </div>
                        <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium truncate">{user?.name}</p>
                            <p className="text-xs text-muted-foreground truncate">{user?.email}</p>
                        </div>
                    </div>
                    <Button variant="outline" size="sm" className="w-full" onClick={handleLogout}>
                        <LogOut className="h-4 w-4 mr-2" />
                        Sair
                    </Button>
                </div>
            </aside>

            {/* Main Content */}
            <main className="flex-1 flex flex-col">
                {/* Header */}
                <header className="p-4 border-b border-border">
                    <div className="flex items-center justify-between">
                        <div>
                            <h1 className="text-xl font-bold">
                                {selectedServer ? selectedServer.name : 'Selecione um servidor'}
                            </h1>
                            {selectedServer && (
                                <p className="text-sm text-muted-foreground">
                                    {selectedServer.host}:{selectedServer.port}
                                </p>
                            )}
                        </div>
                    </div>
                </header>

                {/* Chat Area */}
                <div className="flex-1 overflow-auto p-4">
                    {!selectedServer ? (
                        <div className="h-full flex items-center justify-center">
                            <div className="text-center">
                                <Server className="h-16 w-16 text-muted-foreground mx-auto mb-4" />
                                <h2 className="text-xl font-medium mb-2">Selecione um servidor</h2>
                                <p className="text-muted-foreground">
                                    Escolha um servidor na barra lateral para começar
                                </p>
                            </div>
                        </div>
                    ) : messages.length === 0 ? (
                        <div className="h-full flex items-center justify-center">
                            <div className="text-center max-w-md">
                                <Terminal className="h-16 w-16 text-primary mx-auto mb-4" />
                                <h2 className="text-xl font-medium mb-2">Pronto para ajudar!</h2>
                                <p className="text-muted-foreground mb-4">
                                    Descreva o que você quer fazer em linguagem natural. Por exemplo:
                                </p>
                                <div className="space-y-2 text-sm text-left bg-secondary rounded-lg p-4">
                                    <p><span className="text-terminal-green">→</span> &quot;Instale o Docker e configure&quot;</p>
                                    <p><span className="text-terminal-green">→</span> &quot;Configure o firewall UFW&quot;</p>
                                    <p><span className="text-terminal-green">→</span> &quot;Crie um backup do banco de dados&quot;</p>
                                    <p><span className="text-terminal-green">→</span> &quot;Atualize o sistema&quot;</p>
                                </div>
                            </div>
                        </div>
                    ) : (
                        <div className="space-y-4">
                            {messages.map((message) => (
                                <MessageBubble key={message.id} message={message} />
                            ))}

                            {currentExecution?.requiresConfirmation && !isProcessing && (
                                <div className="flex items-center gap-2 p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
                                    <AlertTriangle className="h-5 w-5 text-yellow-400" />
                                    <span className="text-sm flex-1">Esta execução requer confirmação.</span>
                                    <Button size="sm" variant="outline" onClick={handleCancel}>
                                        <X className="h-4 w-4 mr-1" />
                                        Cancelar
                                    </Button>
                                    <Button size="sm" variant="success" onClick={handleConfirm}>
                                        <Play className="h-4 w-4 mr-1" />
                                        Executar
                                    </Button>
                                </div>
                            )}

                            <div ref={messagesEndRef} />
                        </div>
                    )}
                </div>

                {/* Input Area */}
                {selectedServer && (
                    <div className="p-4 border-t border-border">
                        <div className="flex gap-2">
                            <Input
                                placeholder="Descreva o que você quer fazer..."
                                value={prompt}
                                onChange={(e) => setPrompt(e.target.value)}
                                onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && handleSendPrompt()}
                                disabled={isProcessing}
                                className="flex-1"
                            />
                            <Button onClick={handleSendPrompt} disabled={!prompt.trim() || isProcessing}>
                                {isProcessing ? (
                                    <Loader2 className="h-4 w-4 animate-spin" />
                                ) : (
                                    <Send className="h-4 w-4" />
                                )}
                            </Button>
                        </div>
                    </div>
                )}
            </main>

            {/* Add Server Modal */}
            {showAddServer && (
                <AddServerModal onClose={() => setShowAddServer(false)} />
            )}
        </div>
    );
}

function MessageBubble({ message }: { message: Message }) {
    const getIcon = () => {
        switch (message.type) {
            case 'user': return null;
            case 'assistant': return <Terminal className="h-4 w-4 text-primary" />;
            case 'system': return <AlertTriangle className="h-4 w-4 text-yellow-400" />;
            case 'output': return <CheckCircle className="h-4 w-4 text-terminal-green" />;
            case 'error': return <XCircle className="h-4 w-4 text-terminal-red" />;
            case 'command': return <Terminal className="h-4 w-4 text-terminal-blue" />;
        }
    };

    const getBgColor = () => {
        switch (message.type) {
            case 'user': return 'bg-primary/20 ml-12';
            case 'assistant': return 'bg-card mr-12';
            case 'system': return 'bg-yellow-500/10 border border-yellow-500/30';
            case 'output': return 'bg-green-500/10 font-mono text-sm';
            case 'error': return 'bg-red-500/10 font-mono text-sm text-terminal-red';
            case 'command': return 'bg-blue-500/10 font-mono text-sm';
        }
    };

    return (
        <div className={`p-4 rounded-lg ${getBgColor()}`}>
            {getIcon() && (
                <div className="flex items-center gap-2 mb-2">
                    {getIcon()}
                    <span className="text-xs text-muted-foreground">
                        {message.type === 'assistant' ? 'Assistente IA' : message.type}
                    </span>
                </div>
            )}
            <div className="whitespace-pre-wrap">{message.content}</div>
        </div>
    );
}

function AddServerModal({ onClose }: { onClose: () => void }) {
    const { toast } = useToast();
    const { addServer } = useServersStore();
    const [isLoading, setIsLoading] = useState(false);
    const [formData, setFormData] = useState({
        name: '',
        host: '',
        port: 22,
        username: 'root',
        authType: 'PASSWORD' as 'PASSWORD' | 'KEY',
        password: '',
        privateKey: '',
    });

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsLoading(true);

        try {
            const response = await serversApi.create(formData);
            addServer(response.data);
            toast({
                title: 'Servidor adicionado!',
                description: 'O servidor foi cadastrado com sucesso.',
                variant: 'success',
            });
            onClose();
        } catch (error: any) {
            toast({
                title: 'Erro',
                description: error.response?.data?.message || 'Falha ao adicionar servidor.',
                variant: 'destructive',
            });
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
            <div className="bg-card rounded-lg border border-border p-6 w-full max-w-md">
                <h2 className="text-xl font-bold mb-4">Adicionar Servidor</h2>

                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <label className="text-sm font-medium">Nome</label>
                        <Input
                            value={formData.name}
                            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                            placeholder="Meu Servidor"
                            required
                        />
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <label className="text-sm font-medium">Host</label>
                            <Input
                                value={formData.host}
                                onChange={(e) => setFormData({ ...formData, host: e.target.value })}
                                placeholder="192.168.1.100"
                                required
                            />
                        </div>
                        <div>
                            <label className="text-sm font-medium">Porta</label>
                            <Input
                                type="number"
                                value={formData.port}
                                onChange={(e) => setFormData({ ...formData, port: parseInt(e.target.value) })}
                                placeholder="22"
                            />
                        </div>
                    </div>

                    <div>
                        <label className="text-sm font-medium">Usuário</label>
                        <Input
                            value={formData.username}
                            onChange={(e) => setFormData({ ...formData, username: e.target.value })}
                            placeholder="root"
                            required
                        />
                    </div>

                    <div>
                        <label className="text-sm font-medium">Tipo de Autenticação</label>
                        <select
                            className="w-full h-10 px-3 rounded-md border border-input bg-background text-sm"
                            value={formData.authType}
                            onChange={(e) => setFormData({ ...formData, authType: e.target.value as 'PASSWORD' | 'KEY' })}
                        >
                            <option value="PASSWORD">Senha</option>
                            <option value="KEY">Chave SSH</option>
                        </select>
                    </div>

                    {formData.authType === 'PASSWORD' ? (
                        <div>
                            <label className="text-sm font-medium">Senha</label>
                            <Input
                                type="password"
                                value={formData.password}
                                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                                placeholder="••••••••"
                                required
                            />
                        </div>
                    ) : (
                        <div>
                            <label className="text-sm font-medium">Chave Privada</label>
                            <textarea
                                className="w-full h-24 px-3 py-2 rounded-md border border-input bg-background text-sm font-mono"
                                value={formData.privateKey}
                                onChange={(e) => setFormData({ ...formData, privateKey: e.target.value })}
                                placeholder="-----BEGIN RSA PRIVATE KEY-----"
                                required
                            />
                        </div>
                    )}

                    <div className="flex gap-2 justify-end">
                        <Button type="button" variant="outline" onClick={onClose}>
                            Cancelar
                        </Button>
                        <Button type="submit" disabled={isLoading}>
                            {isLoading ? (
                                <>
                                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                                    Adicionando...
                                </>
                            ) : (
                                'Adicionar'
                            )}
                        </Button>
                    </div>
                </form>
            </div>
        </div>
    );
}
