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

/**
 * The well-known per-OS location of VS Code's User settings.json. setup.sh symlinks
 * this to <repo>/vscode/settings.json, so following that symlink is how we find the
 * repo without needing the user to configure a path at all.
 */
function getUserSettingsPath(): string {
    const home = os.homedir();
    switch (process.platform) {
        case 'darwin':
            return path.join(home, 'Library', 'Application Support', 'Code', 'User', 'settings.json');
        case 'win32':
            return path.join(process.env.APPDATA ?? path.join(home, 'AppData', 'Roaming'), 'Code', 'User', 'settings.json');
        default:
            return path.join(home, '.config', 'Code', 'User', 'settings.json');
    }
}

function detectRepoPathFromSettingsSymlink(): string | null {
    try {
        const settingsPath = getUserSettingsPath();
        if (!fs.lstatSync(settingsPath).isSymbolicLink()) {
            return null;
        }
        const real = fs.realpathSync(settingsPath); // <repo>/vscode/settings.json
        return path.dirname(path.dirname(real)); // <repo>
    } catch {
        return null;
    }
}

function getExtensionsFilePath(): string | null {
    const config = vscode.workspace.getConfiguration('workshopSync');
    const configuredPath = config.get<string>('repoPath', '');
    const repoPath = configuredPath || detectRepoPathFromSettingsSymlink();

    if (!repoPath) {
        vscode.window.showErrorMessage(
            'Workshop Sync: could not auto-detect the workshop repo (settings.json isn\'t a symlink) - set workshopSync.repoPath manually.'
        );
        return null;
    }

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

export function deactivate(): void { }
