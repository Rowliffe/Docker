# Projet d'évaluation Docker — B3 Clermont

> **Module Docker/Conteneurisation** — Projet d'évaluation conforme aux exigences du guide officiel  
> Application web 3-tiers conteneurisée avec stratégie dev/prod, isolation réseau, secrets, persistance et multi-arch.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture & Choix techniques](#architecture--choix-techniques)
- [Prérequis](#prérequis)
- [Installation rapide](#installation-rapide)
- [Lancement en mode développement](#lancement-en-mode-développement-dev)
- [Lancement en mode production locale](#lancement-en-mode-production-locale-prod)
- [Tests de fonctionnement](#tests-de-fonctionnement)
- [Test de persistance](#test-de-persistance-volumes)
- [Registry & Versioning](#registry--stratégie-de-versioning)
- [Optimisations & Bonnes pratiques](#optimisations--bonnes-pratiques)
- [Troubleshooting](#troubleshooting)
- [Structure du projet](#structure-du-projet)

---

## Vue d'ensemble

Ce projet est une **stack Docker multi-conteneurs** complète et fonctionnelle, conçue pour démontrer la maîtrise de la conteneurisation en contexte professionnel :

- **Frontend** : Application React (Vite) qui affiche une instruction récupérée depuis le backend
- **Backend** : API Node.js/Express avec endpoint `/health` et `/api/instruction`
- **Database** : PostgreSQL 15 (Alpine) avec script d'initialisation

### Points clés conformes aux exigences

✅ **Stack multi-conteneurs** (3 services : frontend, backend, DB)  
✅ **2 réseaux isolés** (`front_net` exposé, `back_net` interne — DB isolée)  
✅ **Volumes** (persistance DB avec `named volume`)  
✅ **Dockerfiles multi-stage** (targets `dev` et `prod`, optimisation cache)  
✅ **Multi-arch** (AMD64 + ARM64 via buildx)  
✅ **Non-root** (USER node/nginx dans les Dockerfiles)  
✅ **Healthchecks** (Compose + Dockerfile pour dépendances conditionnelles)  
✅ **Secrets** (Compose secrets + `POSTGRES_PASSWORD_FILE`)  
✅ **Compose dev + prod** (`compose.yaml` + `compose.prod.yaml` avec point d'entrée unique nginx)  
✅ **Documentation complète** (README, troubleshooting, procédures de test)

---

## Architecture & Choix techniques

### Schéma réseau

```
┌─────────────────────────────────────────────────────┐
│                   Hôte (localhost)                  │
│                                                     │
│  MODE DEV                    MODE PROD LOCALE      │
│  :5173 → frontend            :80 → frontend (nginx)│
│  :3001 → backend                  ↓ proxy /api/    │
│                                   backend:3001     │
└─────────────────────────────────────────────────────┘
              ↓                          ↓
┌──────────────────────┐    ┌──────────────────────┐
│    front_net         │    │     back_net         │
│  (exposé)            │    │   (interne, isolé)   │
│                      │    │                      │
│ ┌─────────┐          │    │          ┌────────┐ │
│ │frontend │←─────────┼────┼─────────→│backend │ │
│ └─────────┘          │    │          └────────┘ │
│                      │    │               ↓     │
│                      │    │          ┌────────┐ │
│                      │    │          │   DB   │ │
│                      │    │          │(5432)  │ │
│                      │    │          └────────┘ │
└──────────────────────┘    └──────────────────────┘
```

### Pourquoi ces choix ?

#### 1. **Deux réseaux (front_net + back_net)**
- **front_net** : réseau "exposé" où frontend et backend peuvent communiquer (nécessaire pour les appels API).
- **back_net** : réseau **interne** (`internal: true`) qui isole complètement la DB du monde extérieur. Seul le backend peut y accéder.
- **Avantage** : même si un attaquant compromet le frontend (XSS, etc.), il ne peut pas accéder directement à la DB.

#### 2. **Secrets Compose (vs hardcodés)**
- Le mot de passe DB n'est **jamais en clair** dans le code, les images ou Git.
- Utilisation de `POSTGRES_PASSWORD_FILE` (standard PostgreSQL) pour lire `/run/secrets/db_password`.
- Le fichier `secrets/db_password.txt` est **non commité** (`.gitignore`), remplacé par `secrets/db_password.txt.example` dans le repo.
- **Avantage** : séparation config/secrets, compatible production (Swarm, Kubernetes).

#### 3. **Multi-stage builds + targets dev/prod**
- **Target `dev`** : inclut `nodemon` (backend) et Vite (frontend) pour le hot-reload en développement.
- **Target `prod`** : minimaliste, sans `devDependencies`, avec build Vite statique servi par nginx.
- **Avantage** : images prod ~60% plus légères, surface d'attaque réduite, temps de démarrage optimisé.

#### 4. **Non-root (sécurité)**
- Backend : `USER node` (UID/GID 1000).
- Frontend prod : `USER nginx`, nginx écoute sur `8080` (non-privileged port).
- **Avantage** : si un conteneur est compromis, l'attaquant n'a pas les privilèges root à l'intérieur.

#### 5. **Healthchecks + dépendances conditionnelles**
- Healthchecks permettent à Compose de ne démarrer le backend **que si** la DB répond (`condition: service_healthy`).
- **Avantage** : évite les crashes au démarrage (connexion DB refusée), logs propres, expérience "ça marche du premier coup".

#### 6. **Point d'entrée unique en prod (nginx reverse proxy)**
- En mode "production locale", **seul le frontend nginx** est exposé (`:80`).
- Nginx proxie `/api/*` vers `backend:3001` (réseau interne).
- **Avantage** : architecture réaliste (séparation frontend statique / API backend), CORS simplifié (même origine).

#### 7. **Volume nommé pour la DB**
- `db-data:/var/lib/postgresql/data` persiste les données même après `docker compose down`.
- **Avantage** : pas de perte de données entre redémarrages, backup/restore facile (`docker volume`).

---

## Prérequis

- **Docker Desktop** (Windows/Mac) ou **Docker Engine + Compose plugin** (Linux)
- Version minimale : Docker Compose **v2.20+** (pour support `!override`/`!reset`, sinon compatible v2.0+)

Vérifier :
```bash
docker compose version
```

---

## Installation rapide

### 1) Cloner le repository

```bash
git clone https://github.com/Rowliffe/Docker.git
cd Docker/Exam_docker_V6
```

### 2) Créer la configuration locale (sans secrets en clair)

```bash
# Secret DB (non commité, utilisé par Compose)
cp secrets/db_password.txt.example secrets/db_password.txt

# Variables d'environnement (non commité)
cp .env.example .env
```

> **Important** : `.env` contient uniquement de la **config** (ports, noms DB), **pas de secrets**. Le mot de passe DB est lu via `secrets/db_password.txt` (mécanisme Compose secrets).

### 3) (Optionnel) Personnaliser la config

Éditez `.env` pour changer les ports si nécessaire :
```bash
FRONTEND_PORT=5173
BACKEND_PORT=3001
POSTGRES_USER=postgres
POSTGRES_DB=evaluation
```

---

## Lancement en mode développement (dev)

### Démarrer la stack

```bash
docker compose -f compose.yaml up --build
```

### Services disponibles

- **Frontend (Vite hot-reload)** : `http://localhost:5173`
- **Backend (nodemon auto-restart)** : `http://localhost:3001`
- **DB** : accessible uniquement depuis le backend (isolation réseau)

### Vérification rapide

```bash
curl http://localhost:3001/health
# {"status":"ok"}

curl http://localhost:3001/api/instruction
# {"id":1,"message":"Réalise le docker-compose et branche le front sur le back. Bonne chance !","created_at":"2025-12-20T..."}
```

### Arrêter

```bash
# Ctrl+C ou (en mode détaché)
docker compose -f compose.yaml down
```

---

## Lancement en mode production locale (prod)

### Démarrer en mode prod

```bash
docker compose -f compose.yaml -f compose.prod.yaml up --build
```

> **Fusion de fichiers** : `compose.prod.yaml` override les targets (`dev` → `prod`), supprime les ports backend (non exposé), et configure le frontend nginx en reverse proxy.

### Point d'entrée unique

- **Frontend + API (via nginx)** : `http://localhost` (port 80)
- **Route `/api/*`** : proxiée vers `backend:3001` (réseau interne)
- **Backend** : **non exposé** sur l'hôte (sécurité)

### Vérification bout-en-bout

```bash
curl http://localhost/api/instruction
# {"id":1,"message":"...","created_at":"..."}
```

### Arrêter

```bash
docker compose -f compose.yaml -f compose.prod.yaml down
```

---

## Tests de fonctionnement

### 1. Santé du backend (healthcheck)

```bash
curl http://localhost:3001/health
```

**Réponse attendue** :
```json
{"status":"ok"}
```

### 2. E2E API (backend → DB)

```bash
curl http://localhost:3001/api/instruction
```

**Réponse attendue** :
```json
{
  "id": 1,
  "message": "Réalise le docker-compose et branche le front sur le back. Bonne chance !",
  "created_at": "2025-12-20T17:25:35.078Z"
}
```

### 3. E2E via point d'entrée unique (prod locale)

```bash
curl http://localhost/api/instruction
```

**Réponse attendue** : identique (preuve que nginx proxie correctement vers le backend).

### 4. Frontend React

Ouvrir `http://localhost:5173` (dev) ou `http://localhost` (prod) dans un navigateur.

**Comportement attendu** : affichage du message récupéré depuis l'API.

---

## Test de persistance (volumes)

### Objectif

Prouver que les données survivent au redémarrage des conteneurs grâce au **named volume** `db-data`.

### Procédure

#### 1. Insérer une nouvelle instruction

```bash
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "INSERT INTO instructions(message) VALUES ('persist test');"
```

**Sortie attendue** :
```
INSERT 0 1
```

#### 2. Redémarrer uniquement le conteneur DB

```bash
docker compose -f compose.yaml restart db
```

#### 3. Vérifier que la donnée est toujours présente

```bash
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "SELECT message FROM instructions ORDER BY id DESC LIMIT 1;"
```

**Sortie attendue** :
```
    message
--------------
 persist test
(1 row)
```

> ✅ **Preuve de persistance** : la donnée insérée avant le restart est toujours là (volume `db-data` non supprimé).

### Suppression complète (volumes inclus)

```bash
docker compose -f compose.yaml down -v
```

> **Attention** : `-v` supprime le volume → perte des données.

---

## Registry & Stratégie de versioning

### Choix du registry

**GitHub Container Registry (GHCR)** : `ghcr.io/rowliffe/exam-docker-v6`

**Pourquoi GHCR ?**
- Gratuit pour les repos publics/privés.
- Intégration native GitHub (CI/CD avec GitHub Actions).
- Support multi-arch (manifest lists).

### Stratégie de tagging

#### Convention de nommage

```
ghcr.io/rowliffe/exam-docker-v6-<service>:<tag>
```

- **`<service>`** : `backend`, `frontend`
- **`<tag>`** :
  - `latest` : dernière version stable (main/master)
  - `vX.Y.Z` : version sémantique (ex: `v1.0.0`, `v1.1.0`)
  - `sha-<commit>` : tag immuable basé sur le commit Git (traçabilité)
  - `dev` : build automatique de la branche `develop` (CI/CD)

#### Exemples

```bash
ghcr.io/rowliffe/exam-docker-v6-backend:latest
ghcr.io/rowliffe/exam-docker-v6-backend:v1.0.0
ghcr.io/rowliffe/exam-docker-v6-backend:sha-ac4edf5
ghcr.io/rowliffe/exam-docker-v6-frontend:latest
```

### Build multi-arch (AMD64 + ARM64)

#### Prérequis : buildx

```bash
docker buildx create --use --name multiarch-builder
docker buildx inspect --bootstrap
```

#### Build + push backend (exemple)

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/rowliffe/exam-docker-v6-backend:v1.0.0 \
  --tag ghcr.io/rowliffe/exam-docker-v6-backend:latest \
  --push \
  ./backend
```

#### Build + push frontend (exemple)

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/rowliffe/exam-docker-v6-frontend:v1.0.0 \
  --tag ghcr.io/rowliffe/exam-docker-v6-frontend:latest \
  --build-arg VITE_API_BASE_URL=. \
  --target prod \
  --push \
  ./frontend
```

### Authentification GHCR

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

> **Note** : créer un Personal Access Token avec scope `write:packages` sur GitHub.

### Vérification du manifest multi-arch

```bash
docker buildx imagetools inspect ghcr.io/rowliffe/exam-docker-v6-backend:v1.0.0
```

**Sortie attendue** :
```
Name:      ghcr.io/rowliffe/exam-docker-v6-backend:v1.0.0
MediaType: application/vnd.docker.distribution.manifest.list.v2+json
Digest:    sha256:...

Manifests:
  Name:      ...@sha256:...
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/amd64

  Name:      ...@sha256:...
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/arm64
```

---

## Optimisations & Bonnes pratiques

### 1. Dockerfiles

- ✅ **Multi-stage builds** : séparation install deps / build / runtime.
- ✅ **Optimisation cache** : `COPY package*.json` avant `COPY . .` → rebuild rapide si seul le code change.
- ✅ **`.dockerignore`** : exclut `node_modules`, `.env`, `dist` → build plus rapide, image plus légère.
- ✅ **Layers minimaux** : regroupement des `RUN` quand pertinent (ex: `apk add` + cleanup en 1 layer).

### 2. Sécurité

- ✅ **Non-root** : `USER node`/`nginx` dans tous les conteneurs applicatifs.
- ✅ **Secrets Compose** : pas de mot de passe en clair dans le code ou les images.
- ✅ **Réseau interne** : DB isolée sur `back_net` (flag `internal: true`).
- ✅ **Images Alpine** : surface d'attaque réduite (`node:18-alpine`, `postgres:15-alpine`, `nginx:stable-alpine`).

### 3. Fiabilité

- ✅ **Healthchecks** : `condition: service_healthy` évite les crashs au démarrage.
- ✅ **Dépendances explicites** : `depends_on` avec condition → ordre de démarrage garanti.
- ✅ **Volumes nommés** : persistance DB, pas de perte de données entre redémarrages.

### 4. Developer Experience

- ✅ **Hot-reload** : Vite (frontend) et nodemon (backend) en mode dev.
- ✅ **README complet** : procédures pas-à-pas, troubleshooting, tests.
- ✅ **`.env.example`** : template clair pour la config locale.

---

## Troubleshooting

### Erreur : `secrets/db_password.txt` absent

```
Error: secret "db_password": file "./secrets/db_password.txt" not found
```

**Solution** :
```bash
cp secrets/db_password.txt.example secrets/db_password.txt
```

---

### Port 80 déjà utilisé (mode prod)

```
Error: bind 0.0.0.0:80: address already in use
```

**Solution 1** : libérer le port (ex: arrêter IIS, Apache, nginx local).

**Solution 2** : changer le port dans `compose.prod.yaml` :
```yaml
ports:
  - "8080:8080"  # au lieu de "80:8080"
```

Puis accéder à `http://localhost:8080`.

---

### Healthcheck KO / conteneurs unhealthy

```bash
docker compose -f compose.yaml ps
# backend-1  Up 30s (unhealthy)
```

**Diagnostic** :
```bash
docker compose -f compose.yaml logs backend
```

**Causes fréquentes** :
- Mauvaise `DATABASE_URL` → vérifier les variables d'env.
- DB pas encore ready → attendre 10-20s (healthcheck `retries: 20`).
- Port déjà pris → changer `BACKEND_PORT` dans `.env`.

**Solution** : si les logs montrent une erreur de connexion DB, vérifier `secrets/db_password.txt` et les variables `POSTGRES_*`.

---

### Docker Desktop non démarré (Windows/Mac)

```
Error: error during connect: Get "http://...": open //./pipe/dockerDesktopLinuxEngine: Le fichier spécifié est introuvable.
```

**Solution** : lancer Docker Desktop, attendre qu'il soit en état "Running", puis relancer la commande.

---

### Erreur YAML `!override` / `!reset` non reconnu

```
Error: yaml: unmarshal errors: line X: cannot unmarshal !!str `!override` into ...
```

**Cause** : version Docker Compose trop ancienne (< v2.20).

**Solution 1** : mettre à jour Docker Compose plugin.

**Solution 2** : remplacer `!override` / `!reset` par une approche `profiles` ou séparer complètement les fichiers dev/prod.

---

### Voir les logs en temps réel

```bash
# Tous les services
docker compose -f compose.yaml logs -f

# Un service spécifique
docker compose -f compose.yaml logs -f backend
```

---

### Rebuild forcé (sans cache)

```bash
docker compose -f compose.yaml build --no-cache
docker compose -f compose.yaml up --force-recreate
```

---

## Structure du projet

```
Exam_docker_V6/
├── backend/
│   ├── Dockerfile              # Multi-stage (dev/prod), non-root, healthcheck
│   ├── docker-entrypoint.sh    # Construit DATABASE_URL depuis secret
│   ├── package.json
│   ├── .dockerignore
│   └── src/
│       └── index.js            # API Express (/health, /api/instruction)
├── frontend/
│   ├── Dockerfile              # Multi-stage (dev=Vite, prod=nginx non-root)
│   ├── nginx/
│   │   └── nginx.conf          # Reverse proxy /api/ → backend:3001
│   ├── package.json
│   ├── .dockerignore
│   └── src/
│       ├── App.jsx             # Composant React principal
│       └── main.jsx
├── db/
│   └── init.sql                # Script initialisation PostgreSQL
├── secrets/
│   └── db_password.txt.example # Template (le vrai fichier est .gitignored)
├── compose.yaml                # Mode développement (targets dev)
├── compose.prod.yaml           # Override prod (targets prod, point d'entrée unique)
├── .env.example                # Template variables (ports, config DB)
├── .gitignore                  # Ignore secrets/, .env, node_modules
└── README.md                   # Ce fichier
```

---

## Schéma de la base de données

### Table `instructions`

| Colonne       | Type         | Description                    |
|---------------|--------------|--------------------------------|
| `id`          | SERIAL       | Clé primaire auto-incrémentée |
| `message`     | TEXT         | Message de l'instruction       |
| `created_at`  | TIMESTAMPTZ  | Date de création (UTC)         |

### Exemple de données

```sql
SELECT * FROM instructions;
```

```
 id |                           message                            |        created_at
----+--------------------------------------------------------------+---------------------------
  1 | Réalise le docker-compose et branche le front sur le back.  | 2025-12-20 17:25:35+00
    | Bonne chance !
```

---

## Endpoints API

### `GET /health`

**Description** : healthcheck endpoint (utilisé par Docker healthcheck).

**Réponse** :
```json
{"status":"ok"}
```

---

### `GET /api/instruction`

**Description** : récupère la première instruction de la DB.

**Réponse succès (200)** :
```json
{
  "id": 1,
  "message": "Réalise le docker-compose et branche le front sur le back. Bonne chance !",
  "created_at": "2025-12-20T17:25:35.078Z"
}
```

**Réponse erreur (404)** :
```json
{
  "error": "No instruction found"
}
```

**Réponse erreur DB (500)** :
```json
{
  "error": "Database error"
}
```

---

## Références

- **Guide officiel** : [`projet-final.pdf`](file://projet-final.pdf) — Module Docker/Conteneurisation (Jérémy Marodon, 2025)
- **Docker Compose** : [https://docs.docker.com/compose/](https://docs.docker.com/compose/)
- **Buildx (multi-arch)** : [https://docs.docker.com/buildx/working-with-buildx/](https://docs.docker.com/buildx/working-with-buildx/)
- **GitHub Container Registry** : [https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

---

**Auteur** : Projet d'évaluation B3 Clermont — Module Docker/Conteneurisation  
**Date limite de rendu** : 23 décembre 2025, 23h59  
**Repository** : [https://github.com/Rowliffe/Docker](https://github.com/Rowliffe/Docker)

