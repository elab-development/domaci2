const mysql = require('mysql2/promise');

const dbConfig = {
  host: process.env.DB_HOST || 'mysql-db',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'fuser',
  password: process.env.DB_PASSWORD || 'fpass',
  database: process.env.DB_NAME || 'feedback_db',
  waitForConnections: true,
  connectionLimit: 5,
  queueLimit: 0,
  connectTimeout: 3000
};

let pool;
let initialized = false;

function isDbConfigured() {
  return String(process.env.DB_ENABLED || 'true').toLowerCase() !== 'false';
}

function getPool() {
  if (!pool) {
    pool = mysql.createPool(dbConfig);
  }
  return pool;
}

async function initDb() {
  if (!isDbConfigured()) {
    return { available: false, reason: 'DB_ENABLED=false' };
  }

  try {
    const connection = await getPool().getConnection();
    await connection.query(`
      CREATE TABLE IF NOT EXISTS feedback_metadata (
        id INT AUTO_INCREMENT PRIMARY KEY,
        file_name VARCHAR(255) NOT NULL,
        file_url VARCHAR(500) NOT NULL,
        title VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    connection.release();
    initialized = true;
    return { available: true };
  } catch (error) {
    initialized = false;
    return { available: false, reason: error.message };
  }
}

async function saveMetadata({ fileName, fileUrl, title }) {
  if (!isDbConfigured()) {
    return { saved: false, reason: 'DB_ENABLED=false' };
  }

  try {
    if (!initialized) {
      const initResult = await initDb();
      if (!initResult.available) {
        return { saved: false, reason: initResult.reason };
      }
    }

    const [result] = await getPool().execute(
      'INSERT INTO feedback_metadata (file_name, file_url, title) VALUES (?, ?, ?)',
      [fileName, fileUrl, title]
    );

    return { saved: true, id: result.insertId };
  } catch (error) {
    initialized = false;
    return { saved: false, reason: error.message };
  }
}

async function getMetadata() {
  if (!isDbConfigured()) {
    return { available: false, items: [], reason: 'DB_ENABLED=false' };
  }

  try {
    if (!initialized) {
      const initResult = await initDb();
      if (!initResult.available) {
        return { available: false, items: [], reason: initResult.reason };
      }
    }

    const [rows] = await getPool().query(
      'SELECT id, file_name, file_url, title, created_at FROM feedback_metadata ORDER BY created_at DESC'
    );

    return { available: true, items: rows };
  } catch (error) {
    initialized = false;
    return { available: false, items: [], reason: error.message };
  }
}

module.exports = {
  initDb,
  saveMetadata,
  getMetadata
};
