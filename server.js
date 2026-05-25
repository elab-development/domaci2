const express = require('express');
const fs = require('fs/promises');
const path = require('path');
const { initDb, saveMetadata, getMetadata } = require('./db');

const app = express();
const PORT_EXPOSE = Number(3001);
const FEEDBACK_DIR = process.env.FEEDBACK_DIR || path.join(__dirname, 'feedback');
const BASE_URL = process.env.BASE_URL || `http://localhost:${PORT_EXPOSE}`;
const os = require('os');
const hostname = os.hostname();

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use('/public', express.static(path.join(__dirname, 'public')));
app.use('/feedback-files', express.static(FEEDBACK_DIR));

function renderPage(content) {
  return `<!DOCTYPE html>
<html lang="sr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Feedback Collector</title>
  <link rel="stylesheet" href="/public/style.css" />
</head>
<body>
  <main class="container">
    ${content}
  </main>
</body>
</html>`;
}

function sanitizeFileName(value) {
  return String(value || 'feedback')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9čćšđž\-_\s]/gi, '')
    .replace(/\s+/g, '-')
    .slice(0, 60) || 'feedback';
}

async function listFeedbackFiles() {
  await fs.mkdir(FEEDBACK_DIR, { recursive: true });
  const files = await fs.readdir(FEEDBACK_DIR);
  return files
    .filter((file) => file.endsWith('.txt'))
    .sort()
    .reverse();
}

app.get('/', async (req, res) => {
  const dbStatus = await initDb();

  res.send(renderPage(`
    <section class="card">
      <p class="eyebrow">Docker Volumes & Networking</p>
      <h1>Feedback Collector App</h1>
      <p class="lead">Unesi feedback. Aplikacija uvek kreira TXT fajl, a ako je MySQL baza dostupna, dodatno čuva meta podatke o fajlu.</p>
      <div class="status ${dbStatus.available ? 'ok' : 'warn'}">
        Baza: ${dbStatus.available ? 'dostupna — meta podaci će biti sačuvani' : `nije dostupna — čuva se samo fajl (${dbStatus.reason})`}
      </div>
      <form action="/feedback" method="POST" class="form">
        <label>
          Naslov feedback-a
          <input type="text" name="title" placeholder="npr. Utisci sa vežbi" required />
        </label>
        <label>
          Tekst feedback-a
          <textarea name="message" rows="7" placeholder="Unesite komentar..." required></textarea>
        </label>
        <button type="submit">Pošalji feedback</button>
      </form>
      <div class="links">
        <a href="/feedback">Pregled feedback fajlova</a>
        <a href="/db-status">DB status</a>
      </div>
    </section>
  `));
});

app.post('/feedback', async (req, res) => {
  const { title, message } = req.body;

  if (!title || !message) {
    return res.status(400).send(renderPage(`
      <section class="card">
        <h1>Greška</h1>
        <p>Naslov i tekst feedback-a su obavezni.</p>
        <a href="/">Nazad na formu</a>
      </section>
    `));
  }

  await fs.mkdir(FEEDBACK_DIR, { recursive: true });

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const safeTitle = sanitizeFileName(title);
  const fileName = `${safeTitle}-${timestamp}.txt`;
  const filePath = path.join(FEEDBACK_DIR, fileName);
  const fileUrl = `${BASE_URL}/feedback-files/${encodeURIComponent(fileName)}`;

  const fileContent = [
    `Naslov: ${title}`,
    `Datum: ${new Date().toLocaleString('sr-RS')}`,
    '',
    message,
    `Host: ${hostname}`
  ].join('\n');

  try {
    await fs.writeFile(filePath, fileContent, 'utf8');
  } catch (error) {
    return res.status(500).send(renderPage(`
      <section class="card">
        <h1>Fajl nije kreiran</h1>
        <p>${error.message}</p>
        <a href="/">Nazad na formu</a>
      </section>
    `));
  }

  const metadataResult = await saveMetadata({ fileName, fileUrl, title });

  res.send(renderPage(`
    <section class="card">
      <p class="eyebrow">Feedback je sačuvan</p>
      <h1>Uspešno kreiran fajl</h1>
      <p><strong>Naziv fajla:</strong> ${fileName}</p>
      <p><strong>URL:</strong> <a href="/feedback-files/${encodeURIComponent(fileName)}">${fileUrl}</a></p>
      <div class="status ${metadataResult.saved ? 'ok' : 'warn'}">
        Meta podaci: ${metadataResult.saved ? 'sačuvani u bazi' : `nisu sačuvani u bazi (${metadataResult.reason})`}
      </div>
      <div class="links">
        <a href="/">Novi feedback</a>
        <a href="/feedback">Pregled svih fajlova</a>
      </div>
    </section>
  `));
});

app.get('/feedback', async (req, res) => {
  const files = await listFeedbackFiles();
  const metadata = await getMetadata();

  const fileItems = files.length
    ? files.map((file) => `<li><a href="/feedback-files/${encodeURIComponent(file)}">${file}</a></li>`).join('')
    : '<li>Nema kreiranih feedback fajlova.</li>';

  const metadataRows = metadata.available && metadata.items.length
    ? metadata.items.map((item) => `
        <tr>
          <td>${item.id}</td>
          <td>${item.title}</td>
          <td>${item.file_name}</td>
          <td><a href="${item.file_url}">Otvori</a></td>
          <td>${new Date(item.created_at).toLocaleString('sr-RS')}</td>
        </tr>
      `).join('')
    : `<tr><td colspan="5">${metadata.available ? 'Nema meta podataka u bazi.' : `Baza nije dostupna: ${metadata.reason}`}</td></tr>`;

  res.send(renderPage(`
    <section class="card wide">
      <p class="eyebrow">Pregled</p>
      <h1>Feedback fajlovi i meta podaci</h1>
      <h2>Fajlovi iz volume-a</h2>
      <ul class="file-list">${fileItems}</ul>
      <h2>Meta podaci iz baze</h2>
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Naslov</th>
            <th>Naziv fajla</th>
            <th>URL</th>
            <th>Kreirano</th>
          </tr>
        </thead>
        <tbody>${metadataRows}</tbody>
      </table>
      <div class="links">
        <a href="/">Nazad na formu</a>
      </div>
    </section>
  `));
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'feedback-app' });
});

app.get('/db-status', async (req, res) => {
  const status = await initDb();
  res.json(status);
});

app.get("/api/feedback", async (req, res) => {
  try {
    const metadata = await getMetadata();

    if (!metadata.available) {
      return res.status(503).json({
        success: false,
        databaseAvailable: false,
        message: "Baza nije dostupna. Meta podaci nisu učitani.",
        reason: metadata.reason,
        data: []
      });
    }

    return res.status(200).json({
      success: true,
      databaseAvailable: true,
      count: metadata.items.length,
      data: metadata.items
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      databaseAvailable: false,
      message: "Došlo je do greške prilikom učitavanja meta podataka.",
      reason: error.message,
      data: []
    });
  }
});

app.listen(PORT_EXPOSE, async () => {
  await fs.mkdir(FEEDBACK_DIR, { recursive: true });
  const dbStatus = await initDb();
  console.log(`Feedback app running on port ${PORT_EXPOSE}`);
  console.log(`Feedback directory: ${FEEDBACK_DIR}`);
  console.log(`Database available: ${dbStatus.available}${dbStatus.reason ? ` (${dbStatus.reason})` : ''}`);
});
