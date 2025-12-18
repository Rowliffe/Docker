# Projet d'évaluation Docker

Ce projet est un squelette minimal pour l'évaluation Docker. Il comprend :

- **Frontend** : Application React (Vite) qui affiche une instruction récupérée depuis le backend
- **Backend** : API Node.js/Express qui lit l'instruction depuis PostgreSQL
- **Database** : Script SQL d'initialisation pour PostgreSQL

## Prérequis

- Node.js >= 18
- npm
- PostgreSQL (en local ou via Docker pour les tests)

## Structure du projet

```
├── frontend/          # Application React (Vite)
├── backend/           # API Express
├── db/
│   └── init.sql       # Script d'initialisation PostgreSQL
└── README.md
```

## Installation et lancement

### 1. Base de données

Créez une base de données PostgreSQL et exécutez le script d'initialisation :

```bash
psql -U postgres -d evaluation -f db/init.sql
```

### 2. Backend

```bash
cd backend

# Copier le fichier d'environnement
cp .env.example .env

# Éditer .env avec vos identifiants PostgreSQL
# DATABASE_URL=postgresql://postgres:password@localhost:5432/evaluation

# Installer les dépendances
npm install

# Lancer en mode développement
npm run dev
```

Le backend sera accessible sur `http://localhost:3001`.

### 3. Frontend

```bash
cd frontend

# Installer les dépendances
npm install

# Lancer en mode développement
npm run dev
```

Le frontend sera accessible sur `http://localhost:5173`.

## Configuration

### Backend

Variables d'environnement (fichier `backend/.env`) :

| Variable | Description | Exemple |
|----------|-------------|---------|
| `DATABASE_URL` | URL de connexion PostgreSQL | `postgresql://postgres:password@localhost:5432/evaluation` |
| `PORT` | Port du serveur Express | `3001` |

### Frontend

Variables d'environnement (fichier `frontend/.env`) :

| Variable | Description | Exemple |
|----------|-------------|---------|
| `VITE_API_BASE_URL` | URL du backend | `http://localhost:3001` |

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

## Votre mission

**Vous devez créer les Dockerfiles et le docker-compose.yaml pour conteneuriser cette application.**

Consultez le guide d'évaluation pour les exigences détaillées.

## Docker

Instructions pour lancer l'application avec Docker Compose :

1. Construire et démarrer les conteneurs :

```bash
docker compose up --build
```

2. Accéder aux services depuis l'hôte :

- Frontend : http://localhost:5173
- Backend : http://localhost:3001
- PostgreSQL : port 5432 (user: `postgres`, password: `postgres`, db: `evaluation`)

3. Pour stopper et supprimer les conteneurs et volumes :

```bash
docker compose down -v
```

Remarques :

- Le fichier `docker-compose.yml` à la racine orchestre `db`, `backend` et `frontend`.
- Si vous voulez modifier les identifiants PostgreSQL, mettez à jour les variables d'environnement dans le service `db` du `docker-compose.yml`.

