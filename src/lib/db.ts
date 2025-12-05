import Database from 'better-sqlite3';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync, mkdirSync, readFileSync } from 'fs';

// Get the project root directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..', '..');

// Database path - configurable via environment variable
const dbPath = process.env.DATABASE_PATH || join(projectRoot, 'data', 'pbnj.db');

// Ensure data directory exists
const dataDir = dirname(dbPath);
if (!existsSync(dataDir)) {
  mkdirSync(dataDir, { recursive: true });
}

// Create or open the database
const db = new Database(dbPath);

// Enable WAL mode for better concurrent performance
db.pragma('journal_mode = WAL');

// Initialize the schema if needed
function initSchema() {
  const schemaPath = join(projectRoot, 'schema', 'schema.sql');
  if (existsSync(schemaPath)) {
    const schema = readFileSync(schemaPath, 'utf-8');
    db.exec(schema);
  } else {
    // Fallback schema if file doesn't exist
    db.exec(`
      CREATE TABLE IF NOT EXISTS pastes (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        language TEXT,
        updated INTEGER NOT NULL,
        filename TEXT,
        is_private INTEGER DEFAULT 0,
        secret_key TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_updated ON pastes(updated DESC);
    `);
  }
}

// Initialize on first import
initSchema();

// Export a wrapper that mimics the D1 API for easier migration
export interface DBResult<T> {
  results: T[];
  success: boolean;
  meta: {
    changes: number;
    last_row_id: number;
  };
}

export const database = {
  prepare(sql: string) {
    const stmt = db.prepare(sql);
    return {
      bind(...params: any[]) {
        return {
          first<T = any>(): T | null {
            return stmt.get(...params) as T | null;
          },
          all<T = any>(): DBResult<T> {
            const results = stmt.all(...params) as T[];
            return {
              results,
              success: true,
              meta: { changes: 0, last_row_id: 0 },
            };
          },
          run() {
            const info = stmt.run(...params);
            return {
              success: true,
              meta: {
                changes: info.changes,
                last_row_id: info.lastInsertRowid,
              },
            };
          },
        };
      },
      // For queries without parameters
      first<T = any>(): T | null {
        return stmt.get() as T | null;
      },
      all<T = any>(): DBResult<T> {
        const results = stmt.all() as T[];
        return {
          results,
          success: true,
          meta: { changes: 0, last_row_id: 0 },
        };
      },
      run() {
        const info = stmt.run();
        return {
          success: true,
          meta: {
            changes: info.changes,
            last_row_id: info.lastInsertRowid,
          },
        };
      },
    };
  },
};

export default database;
