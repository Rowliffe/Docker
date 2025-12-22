# Projet Docker - B3 Clermont

Application web React + Node.js + PostgreSQL conteneurisée. **Rendu : 23 décembre 2025, 23h59**.

## Stack

- **Frontend** : React (Vite) → nginx en prod
- **Backend** : Node.js/Express  
- **Database** : PostgreSQL 15

**Conformité** : 3 conteneurs, 2 réseaux (DB isolée), volumes, multi-stage, multi-arch (AMD64/ARM64), non-root, secrets, healthchecks, compose dev+prod.

## Prérequis

Docker Compose v2.0+ (`docker compose version`)

## Architecture

**Dev** : Frontend :5173, Backend :3001 (hot-reload)  
**Prod** : Point d'entrée unique :80 (nginx reverse proxy → backend)

**Réseaux** :
- `front_net` : frontend ↔ backend  
- `back_net` (internal) : backend ↔ DB

## Installation

```bash
git clone https://github.com/Rowliffe/Docker.git
cd Docker/Exam_docker_V6

# Créer secret DB (non commité)
cp secrets/db_password.txt.example secrets/db_password.txt

# Créer .env (non commité)
cp .env.example .env
```

> `.env` = config (ports), `secrets/db_password.txt` = mot de passe (mécanisme Compose secrets).

## Mode développement

```bash
docker compose -f compose.yaml up --build
```

**Accès** : Frontend http://localhost:5173, Backend http://localhost:3001

**Vérifier** :
```bash
curl http://localhost:3001/health          # {"status":"ok"}
curl http://localhost:3001/api/instruction # Données DB
```

**Arrêter** : `docker compose -f compose.yaml down`

## Mode production locale

```bash
docker compose -f compose.yaml -f compose.prod.yaml up --build
```

**Accès** : Point d'entrée unique http://localhost (nginx reverse proxy)

**Vérifier** : `curl http://localhost/api/instruction` (nginx → backend:3001)

## Tests

**1. Healthcheck** : `curl http://localhost:3001/health` → `{"status":"ok"}`

**2. API + DB** : `curl http://localhost:3001/api/instruction` → données

**3. Frontend** : http://localhost:5173 (dev) ou http://localhost (prod)

**4. Persistance (volume db-data)** :
```bash
# Insérer
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "INSERT INTO instructions(message) VALUES ('test');"

# Redémarrer
docker compose -f compose.yaml restart db

# Vérifier (donnée toujours là)
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "SELECT message FROM instructions ORDER BY id DESC LIMIT 1;"
```

## Build multi-arch (AMD64 + ARM64)

**Configuration initiale** (si pas déjà fait) :
```bash
docker buildx create --use --name multiarch-builder
docker buildx inspect --bootstrap
```

**Build backend** :
```bash
docker buildx build --platform linux/amd64,linux/arm64 --target prod -t exam-docker-v6-backend:latest ./backend
```

**Build frontend** :
```bash
docker buildx build --platform linux/amd64,linux/arm64 --target prod --build-arg VITE_API_BASE_URL=. -t exam-docker-v6-frontend:latest ./frontend
```

## Registry & Versioning

**Registry** : GitHub Container Registry (GHCR) `ghcr.io/rowliffe/exam-docker-v6`

**Tags** :
- `latest` : version stable (main)
- `v1.0.0`, `v1.1.0` : versions sémantiques
- `sha-<commit>` : tag immuable (permet la traçabilité)

**Docker Hub** :
```bash
docker pull rowliffe/exam-docker-v6-backend
```
```bash
docker pull rowliffe/exam-docker-v6-frontend
```

**Push backend** :
```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/rowliffe/exam-docker-v6-backend:v1.0.0 \
  --tag ghcr.io/rowliffe/exam-docker-v6-backend:latest \
  --push \
  ./backend
```

**Push frontend** :
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

**Vérifier manifest** :
```bash
docker buildx imagetools inspect ghcr.io/rowliffe/exam-docker-v6-backend:v1.0.0
# Doit afficher : Platform: linux/amd64, Platform: linux/arm64
```

## Optimisations

**Dockerfiles** :
- Multi-stage builds (deps/build/runtime séparés)
- Cache optimisé (`COPY package*.json` avant `COPY . .`)
- `.dockerignore` (exclut node_modules, .env, dist)

**Sécurité** :
- Non-root (USER node/nginx)
- Secrets Compose (pas de mots de passe en clair)
- Réseau interne (DB isolée, flag `internal: true`)
- Images Alpine (surface d'attaque réduite)

**Fiabilité** :
- Healthchecks + `condition: service_healthy`
- Volumes nommés (persistance DB)

## Troubleshooting

**Secret manquant** :
```
Error: secret "db_password": file "./secrets/db_password.txt" not found
```
→ `cp secrets/db_password.txt.example secrets/db_password.txt`

**Port 80 utilisé** :
```
Error: bind 0.0.0.0:80: address already in use
```
→ Changer port dans `compose.prod.yaml` : `"8080:8080"` puis http://localhost:8080

**Conteneur unhealthy** :
```bash
docker compose ps  # backend (unhealthy)
docker compose logs backend
```
→ Vérifier `secrets/db_password.txt`, attendre 10-20s, ou changer `BACKEND_PORT` dans `.env`

**Docker Desktop non démarré** :
```
Error: open //./pipe/dockerDesktopLinuxEngine
```
→ Lancer Docker Desktop et attendre "Running"

**Logs** : `docker compose -f compose.yaml logs -f [backend|frontend|db]`

**Rebuild sans cache** : `docker compose -f compose.yaml build --no-cache`

## Choix techniques

**Multi-stage** : Target `dev` (hot-reload, nodemon/Vite) vs target `prod` (minimal, sans devDependencies). Images prod ~60% plus légères.

**Secrets** : `POSTGRES_PASSWORD_FILE` + Compose secrets → pas de mot de passe en clair (compatible Swarm/K8s).

**2 réseaux** : `back_net` (internal) isole complètement la DB. Même si le frontend est compromis (XSS), pas d'accès direct DB.

**Healthchecks** : `condition: service_healthy` → backend attend que DB réponde, évite les erreurs de connexion au démarrage.

**Nginx reverse proxy (prod)** : Point d'entrée unique, backend non exposé, CORS simplifié (même origine).

## API

**GET /health** : `{"status":"ok"}`

**GET /api/instruction** : Données DB
```json
{
  "id": 1,
  "message": "Réalise le docker-compose et branche le front sur le back. Bonne chance !",
  "created_at": "2025-12-20T17:25:35.078Z"
}
```

## Base de données

**Table** : `instructions` (id SERIAL, message TEXT, created_at TIMESTAMPTZ)

**Accès** :
```bash
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "SELECT * FROM instructions;"
```

## Structure

```
Exam_docker_V6/
├── backend/
│   ├── Dockerfile              # Multi-stage (dev/prod), non-root
│   ├── docker-entrypoint.sh
│   └── src/index.js
├── frontend/
│   ├── Dockerfile              # Multi-stage (dev=Vite, prod=nginx)
│   ├── nginx/nginx.conf
│   └── src/
├── db/init.sql
├── secrets/db_password.txt.example
├── compose.yaml                # Dev
├── compose.prod.yaml           # Prod locale
├── .env.example
└── README.md
```

## Références

- **Compose** : https://docs.docker.com/compose/
- **Buildx** : https://docs.docker.com/buildx/working-with-buildx/
- **GHCR** : https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry

---

**Repository** : https://github.com/Rowliffe/Docker  
**Date limite** : 23 décembre 2025, 23h59
