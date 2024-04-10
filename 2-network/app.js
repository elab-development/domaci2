const express = require('express');
const bodyParser = require('body-parser');
const mysql = require('mysql');
const axios = require('axios');

const app = express();
const port = 3000;

app.use(bodyParser.json());

// MySQL connection setup
const connection = mysql.createConnection({
  host: '172.17.0.1', // Uneti naziv kontejnera koji pokreće bazu
  user: 'novi', 
  password: 'novi',
  database: 'swpreferences'
});

connection.connect(err => {
    if (err) throw err;
    console.log('Connected to the database.');
  
    const createTableSql = `
      CREATE TABLE IF NOT EXISTS preferences (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        type VARCHAR(100) NOT NULL,
        url VARCHAR(100) NOT NULL
      )
    `;
  
    connection.query(createTableSql, (err, result) => {
      if (err) throw err;
      console.log("Table 'preferences' is ready.");
    });
  });


// Endpoint to get all preferences
app.get('/preferences', (req, res) => {
  connection.query('SELECT * FROM preferences', (error, results) => {
    if (error) throw error;
    res.json(results);
  });
});

// Endpoint to add a preference
app.post('/preferences', (req, res) => {
  const { name, type, url } = req.body;
  const query = 'INSERT INTO preferences (name, type, url) VALUES (?, ?, ?)';
  connection.query(query, [name, type, url], (error, results) => {
    if (error) throw error;
    res.status(201).send(`Preference added with ID: ${results.insertId}`);
  });
});

// Endpoint to delete a preference
app.delete('/preferences/:id', (req, res) => {
  const { id } = req.params;
  const query = 'DELETE FROM preferences WHERE id = ?';
  connection.query(query, [id], (error, results) => {
    if (error) throw error;
    res.send(`Preference with ID ${id} deleted.`);
  });
});

// Endpoint to update a preference
app.put('/preferences/:id', (req, res) => {
  const { id } = req.params;
  const { name, type, url } = req.body;
  const query = 'UPDATE preferences SET name = ?, type = ?, url = ? WHERE id = ?';
  connection.query(query, [name, type, url, id], (error, results) => {
    if (error) throw error;
    res.send(`Preference with ID ${id} updated.`);
  });
});

// Endpoint to fetch movies from an external API

app.get('/movies', async (req, res) => {
  try {
    const response = await axios.get('https://swapi.dev/api/films');
    res.status(200).json({ movies: response.data });
  } catch (error) {
    res.status(500).json({ message: 'Something went wrong.' });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});