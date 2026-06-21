import * as vscode from 'vscode';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

function getExtensionsList(): string[] {
    return vscode.extensions.all
        .filter(ext => !ext.packageJSON['isBuiltin'])
        .map(ext => ext.id)
        .sort();
}

function getExtensionsFilePath(): string | null {
    const config = vscode.workspace.getConfiguration('workshopSync');
    const repoPath = config.get<string>('repoPath', '~/Documents_Public/repos_personal/workshop');
    const expanded = repoPath.replace(/^~/, os.homedir());
    const filePath = path.join(expanded, 'vscode', 'extensions.txt');

    if (!fs.existsSync(path.dirname(filePath))) {
        vscode.window.showErrorMessage(
            `Workshop Sync: path not found — ${path.dirname(filePath)}. Check workshopSync.repoPath in settings.`
        );
        return null;
    }

    return filePath;
}

function syncExtensions(): void {
    const filePath = getExtensionsFilePath();
    if (!filePath) {
        return;
    }

    const extensions = getExtensionsList();
    fs.writeFileSync(filePath, extensions.join('\n') + '\n', 'utf8');
}

export function activate(context: vscode.ExtensionContext): void {
    // Sync once on startup
    syncExtensions();

    // Sync whenever extensions are installed or uninstalled
    context.subscriptions.push(
        vscode.extensions.onDidChange(() => {
            syncExtensions();
        })
    );
}

export function deactivate(): void {}
