# Feedback Collector App

Jednostavna Node.js/Express aplikacija za demonstraciju Docker `volumes` i `networking` koncepata.

Aplikacija ima jedan UI za unos feedback-a. Nakon slanja forme aplikacija uvek kreira `.txt` fajl. Ako je MySQL baza dostupna, aplikacija dodatno čuva meta podatke o fajlu u bazi.

## Koncept

- **Volumes deo:** feedback se čuva kao `.txt` fajl u folderu `/app/feedback`, koji je povezan sa Docker named volume-om.
- **Networking deo:** aplikacija komunicira sa MySQL bazom preko Docker mreže i naziva servisa `mysql-db`.
- **Graceful fallback:** ako baza nije dostupna ili je isključena, aplikacija nastavlja da radi i čuva samo fajl.

## Struktura projekta

```text

├── Dockerfile
├── package.json
├── server.js
├── db.js
├── public/
│   └── style.css
└── feedback/
└── README.md
```


## Rute

| Ruta | Opis |
|---|---|
| `GET /` | Prikaz feedback forme |
| `POST /feedback` | Slanje feedback-a i kreiranje fajla |
| `GET /feedback` | Pregled kreiranih fajlova i meta podataka iz baze |
| `GET /feedback-files/:fileName` | Otvaranje pojedinačnog `.txt` fajla |
| `GET /health` | Provera da li aplikacija radi |
| `GET /db-status` | Provera da li je baza dostupna |
| `GET /api/feedback` | Pregled meta podataka iz baze u JSON formatu |

## Tabela u bazi

Aplikacija automatski kreira tabelu `feedback_metadata` ako baza postoji.

```sql
CREATE TABLE IF NOT EXISTS feedback_metadata (
  id INT AUTO_INCREMENT PRIMARY KEY,
  file_name VARCHAR(255) NOT NULL,
  file_url VARCHAR(500) NOT NULL,
  title VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```
