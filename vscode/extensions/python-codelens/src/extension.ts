import * as vscode from 'vscode';

const SYMBOL_PATTERN = /^(\s*)(class|def)\s+(\w+)/;

interface CachedCount {
    count: number;
}

class PythonCodeLens extends vscode.CodeLens {
    constructor(range: vscode.Range, public readonly documentUri: vscode.Uri) {
        super(range);
    }
}

export class PythonReferenceLensProvider implements vscode.CodeLensProvider {
    private _onDidChangeCodeLenses = new vscode.EventEmitter<void>();
    public readonly onDidChangeCodeLenses = this._onDidChangeCodeLenses.event;

    private _cache = new Map<string, CachedCount>();
    private _disposables: vscode.Disposable[] = [];

    constructor() {
        // Invalidate per-line cache as the user types
        this._disposables.push(
            vscode.workspace.onDidChangeTextDocument(e => {
                if (e.document.languageId === 'python') {
                    this._clearCacheForUri(e.document.uri.toString());
                    this._onDidChangeCodeLenses.fire();
                }
            })
        );

        // Full cache clear on save — references in other files may have changed
        this._disposables.push(
            vscode.workspace.onDidSaveTextDocument(doc => {
                if (doc.languageId === 'python') {
                    this._cache.clear();
                    this._onDidChangeCodeLenses.fire();
                }
            })
        );

        // Refresh when config changes
        this._disposables.push(
            vscode.workspace.onDidChangeConfiguration(e => {
                if (e.affectsConfiguration('pythonCodelens')) {
                    this._cache.clear();
                    this._onDidChangeCodeLenses.fire();
                }
            })
        );
    }

    private _clearCacheForUri(uri: string): void {
        for (const key of this._cache.keys()) {
            if (key.startsWith(uri + ':')) {
                this._cache.delete(key);
            }
        }
    }

    provideCodeLenses(document: vscode.TextDocument): vscode.CodeLens[] {
        const config = vscode.workspace.getConfiguration('pythonCodelens');
        if (!config.get<boolean>('enabled', true)) {
            return [];
        }

        const lenses: vscode.CodeLens[] = [];

        for (let i = 0; i < document.lineCount; i++) {
            const line = document.lineAt(i);
            if (SYMBOL_PATTERN.test(line.text)) {
                const range = new vscode.Range(i, 0, i, line.text.length);
                lenses.push(new PythonCodeLens(range, document.uri));
            }
        }

        return lenses;
    }

    async resolveCodeLens(
        lens: vscode.CodeLens,
        token: vscode.CancellationToken
    ): Promise<vscode.CodeLens | null> {
        const { documentUri } = lens as PythonCodeLens;
        const document = await vscode.workspace.openTextDocument(documentUri);

        const lineText = document.lineAt(lens.range.start.line).text;
        const match = lineText.match(SYMBOL_PATTERN);
        if (!match) {
            return null;
        }

        const keyword = match[2];
        const symbolName = match[3];

        // Find the exact column of the symbol name
        const keywordIndex = lineText.indexOf(keyword);
        const symbolIndex = lineText.indexOf(symbolName, keywordIndex + keyword.length);
        const symbolPosition = new vscode.Position(lens.range.start.line, symbolIndex);

        const cacheKey = `${documentUri.toString()}:${lens.range.start.line}:${symbolName}`;
        const cached = this._cache.get(cacheKey);
        if (cached !== undefined) {
            return this._buildLens(lens, documentUri, symbolPosition, cached.count);
        }

        if (token.isCancellationRequested) {
            return null;
        }

        const locations = await vscode.commands.executeCommand<vscode.Location[]>(
            'vscode.executeReferenceProvider',
            documentUri,
            symbolPosition
        );

        if (token.isCancellationRequested) {
            return null;
        }

        // Filter out the definition line itself
        const references = (locations ?? []).filter(loc => {
            const sameFile = loc.uri.toString() === documentUri.toString();
            const sameLine = loc.range.start.line === lens.range.start.line;
            return !(sameFile && sameLine);
        });

        const count = references.length;
        if (count > 0) {
            this._cache.set(cacheKey, { count });
        }

        return this._buildLens(lens, documentUri, symbolPosition, count);
    }

    private _buildLens(
        lens: vscode.CodeLens,
        uri: vscode.Uri,
        position: vscode.Position,
        count: number
    ): vscode.CodeLens {
        lens.command = {
            title: `${count} ${count === 1 ? 'reference' : 'references'}`,
            command: 'editor.action.findReferences',
            arguments: [uri, position]
        };
        return lens;
    }

    dispose(): void {
        this._disposables.forEach(d => d.dispose());
        this._onDidChangeCodeLenses.dispose();
    }
}

export function activate(context: vscode.ExtensionContext): void {
    const provider = new PythonReferenceLensProvider();
    context.subscriptions.push(
        vscode.languages.registerCodeLensProvider(
            { language: 'python', scheme: 'file' },
            provider
        ),
        provider
    );
}

export function deactivate(): void {}
