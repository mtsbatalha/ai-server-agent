import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { NodeSSH, SSHExecCommandResponse } from 'node-ssh';
import { AuthType } from '@prisma/client';

export interface SSHCredentials {
    host: string;
    port: number;
    username: string;
    authType: AuthType;
    password: string | null;
    privateKey: string | null;
    passphrase: string | null;
}

export interface CommandResult {
    stdout: string;
    stderr: string;
    code: number | null;
    success: boolean;
}

@Injectable()
export class SshService {
    private readonly logger = new Logger(SshService.name);
    private connections: Map<string, NodeSSH> = new Map();

    async testConnection(
        credentials: SSHCredentials,
        timeout: number = 10,
    ): Promise<{ success: boolean; message: string; fingerprint?: string }> {
        const ssh = new NodeSSH();

        try {
            const config = this.buildConnectionConfig(credentials, timeout * 1000);

            await ssh.connect(config);

            // Get server fingerprint
            const result = await ssh.execCommand('hostname');
            const hostname = result.stdout.trim();

            ssh.dispose();

            return {
                success: true,
                message: `Successfully connected to ${hostname}`,
                fingerprint: hostname,
            };
        } catch (error) {
            this.logger.error(`SSH connection failed: ${error.message}`);
            return {
                success: false,
                message: error.message || 'Connection failed',
            };
        } finally {
            if (ssh.isConnected()) {
                ssh.dispose();
            }
        }
    }

    async connect(serverId: string, credentials: SSHCredentials): Promise<NodeSSH> {
        // Check if already connected
        const existing = this.connections.get(serverId);
        if (existing && existing.isConnected()) {
            return existing;
        }

        const ssh = new NodeSSH();
        const config = this.buildConnectionConfig(credentials, 30000);

        try {
            await ssh.connect(config);
            this.connections.set(serverId, ssh);
            this.logger.log(`SSH connected to ${credentials.host}`);
            return ssh;
        } catch (error) {
            this.logger.error(`Failed to connect to ${credentials.host}: ${error.message}`);
            throw new BadRequestException(`SSH connection failed: ${error.message}`);
        }
    }

    async disconnect(serverId: string): Promise<void> {
        const ssh = this.connections.get(serverId);
        if (ssh) {
            if (ssh.isConnected()) {
                ssh.dispose();
            }
            this.connections.delete(serverId);
            this.logger.log(`SSH disconnected from server ${serverId}`);
        }
    }

    async executeCommand(
        serverId: string,
        command: string,
        credentials: SSHCredentials,
    ): Promise<CommandResult> {
        const ssh = await this.connect(serverId, credentials);

        try {
            const result = await ssh.execCommand(command, {
                cwd: '/',
                execOptions: { pty: true },
            });

            return {
                stdout: result.stdout,
                stderr: result.stderr,
                code: result.code,
                success: result.code === 0,
            };
        } catch (error) {
            this.logger.error(`Command execution failed: ${error.message}`);
            return {
                stdout: '',
                stderr: error.message,
                code: -1,
                success: false,
            };
        }
    }

    async executeCommands(
        serverId: string,
        commands: string[],
        credentials: SSHCredentials,
        onOutput?: (output: string, isError: boolean) => void,
    ): Promise<CommandResult[]> {
        const results: CommandResult[] = [];

        for (const command of commands) {
            if (onOutput) {
                onOutput(`$ ${command}\n`, false);
            }

            const result = await this.executeCommand(serverId, command, credentials);
            results.push(result);

            if (onOutput) {
                if (result.stdout) {
                    onOutput(result.stdout + '\n', false);
                }
                if (result.stderr) {
                    onOutput(result.stderr + '\n', true);
                }
            }

            // Stop execution if command failed
            if (!result.success) {
                break;
            }
        }

        return results;
    }

    private buildConnectionConfig(credentials: SSHCredentials, timeout: number) {
        const config: any = {
            host: credentials.host,
            port: credentials.port,
            username: credentials.username,
            readyTimeout: timeout,
            keepaliveInterval: 10000,
        };

        if (credentials.authType === AuthType.PASSWORD) {
            config.password = credentials.password;
        } else {
            config.privateKey = credentials.privateKey;
            if (credentials.passphrase) {
                config.passphrase = credentials.passphrase;
            }
        }

        return config;
    }

    isConnected(serverId: string): boolean {
        const ssh = this.connections.get(serverId);
        return ssh ? ssh.isConnected() : false;
    }

    async disconnectAll(): Promise<void> {
        for (const [serverId, ssh] of this.connections) {
            if (ssh.isConnected()) {
                ssh.dispose();
            }
        }
        this.connections.clear();
        this.logger.log('All SSH connections closed');
    }
}
