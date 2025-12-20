# Projet d'évaluation Docker

Ce projet est un squelette minimal pour l'évaluation Docker. Il comprend :

- **Frontend** : Application React (Vite) qui affiche une instruction récupérée depuis le backend
- **Backend** : API Node.js/Express qui lit l'instruction depuis PostgreSQL
- **Database** : Script SQL d'initialisation pour PostgreSQL

## Prérequis

- Docker Desktop / Docker Engine avec la commande `docker compose`

## Structure du projet

```
├── frontend/          # Application React (Vite)
├── backend/           # API Express
├── db/
│   └── init.sql       # Script d'initialisation PostgreSQL
├── compose.yaml       # Mode développement (targets dev)
├── compose.prod.yaml  # "Production locale" (targets prod)
├── secrets/
│   └── db_password.txt.example
└── README.md
```

## Installation rapide (obligatoire)

### 1) Créer la configuration (sans secrets en clair)

- Créez le secret local (non commité) :

```bash
cp secrets/db_password.txt.example secrets/db_password.txt
```

- Créez votre fichier `.env` local (non commité) :

```bash
cp .env.example .env
```

> Important : `.env` ne contient **pas** de secret. Le mot de passe DB est lu via `secrets/db_password.txt` (Compose secrets).

## Lancement en mode développement (dev)

```bash
docker compose -f compose.yaml up --build
```

- Frontend (Vite) : `http://localhost:5173`
- Backend : `http://localhost:3001`

## Lancement en mode "production locale" (prod)

```bash
docker compose -f compose.yaml -f compose.prod.yaml up --build
```

- Point d’entrée unique : `http://localhost` (nginx)
- API : `http://localhost/api/instruction` (proxy nginx -> backend)

## Endpoint API

### GET /api/instruction

Récupère la première instruction de la base de données.

**Réponse succès (200)** :
```json
{
  "id": 1,
  "message": "Réalise le docker-compose et branche le front sur le back. Bonne chance !",
  "created_at": "2024-12-17T12:00:00.000Z"
}
```

**Réponse erreur (404)** :
```json
{
  "error": "No instruction found"
}
```

## Schéma de la base de données

Table `instructions` :

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | SERIAL | Clé primaire auto-incrémentée |
| `message` | TEXT | Message de l'instruction |
| `created_at` | TIMESTAMPTZ | Date de création |

## Tests de fonctionnement (obligatoire)

- **Santé backend** :

```bash
curl http://localhost:3001/health
```

- **E2E API (backend -> DB)** :

```bash
curl http://localhost:3001/api/instruction
```

- **E2E via point d’entrée unique (prod locale)** :

```bash
curl http://localhost/api/instruction
```

## Test de persistance (obligatoire)

1) Insérer une nouvelle instruction :

```bash
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "INSERT INTO instructions(message) VALUES ('persist test');"
```

2) Redémarrer uniquement la DB :

```bash
docker compose -f compose.yaml restart db
```

3) Vérifier que la donnée est toujours là (preuve de volume) :

```bash
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "SELECT message FROM instructions ORDER BY id DESC LIMIT 1;"
```

## Multi-arch (amd64 + arm64) (obligatoire)

Exemple de build multi-arch avec Buildx (à adapter à votre registry) :

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t mon-registry/mon-image:1.0.0 ./backend
docker buildx build --platform linux/amd64,linux/arm64 -t mon-registry/mon-image:1.0.0 ./frontend
```

## Troubleshooting (obligatoire)

- **Erreur secret manquant** (`secrets/db_password.txt` absent) :
  - Vérifiez que `secrets/db_password.txt` existe (copie depuis `secrets/db_password.txt.example`).
- **Port 80 déjà utilisé** :
  - Changez le mapping du frontend dans `compose.prod.yaml` (ex : `8080:8080`) ou libérez le port.
- **Healthcheck KO / dépendances** :
  - Inspectez : `docker compose -f compose.yaml ps` puis `docker compose -f compose.yaml logs -f backend db frontend`
- **Docker Desktop non démarré** :
  - Lancez Docker Desktop puis relancez `docker compose ...`.
- **Erreur YAML liée à `!override` / `!reset`** :
  - Mettez à jour Docker Compose (plugin) vers une version récente, ou basculez sur une approche `profiles` (si imposé par l’environnement).

