require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3001;

if (!process.env.DATABASE_URL) {
  console.error('ERROR: DATABASE_URL is not defined');
  console.error('Please create a .env file with DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DBNAME');
  process.exit(1);
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

app.use(cors());
app.use(express.json());

app.get('/api/instruction', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM instructions ORDER BY id ASC LIMIT 1');
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'No instruction found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

app.listen(port, () => {
  console.log(`Backend running on http://localhost:${port}`);
});
