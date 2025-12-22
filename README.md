# Projet Docker - Évaluation B3 Clermont

**Module** : Docker/Conteneurisation  
**Auteur** : Projet d'évaluation  
**Date limite** : 23 décembre 2025, 23h59

## Description

Application web conteneurisée avec React (frontend), Node.js/Express (backend) et PostgreSQL (DB). Le projet respecte toutes les exigences du guide d'évaluation.

### Ce qui est inclus

- 3 conteneurs (frontend, backend, database)
- 2 réseaux (front_net exposé, back_net interne)
- Volumes pour la persistance des données
- Dockerfiles multi-stage avec targets dev/prod
- Support multi-architecture (AMD64 + ARM64)
- Exécution non-root
- Healthchecks sur tous les services
- Gestion des secrets (pas de mots de passe en clair)
- Mode dev + mode prod locale
- Documentation complète

## Prérequis

- Docker Desktop (Windows/Mac) ou Docker Engine + Compose plugin (Linux)
- Docker Compose v2.0+

Vérifier la version :
```bash
docker compose version
```

## Structure du projet

```
Exam_docker_V6/
├── backend/
│   ├── Dockerfile              # Multi-stage (dev/prod), non-root
│   ├── docker-entrypoint.sh    # Construction DATABASE_URL depuis secret
│   ├── package.json
│   └── src/index.js            # API Express
├── frontend/
│   ├── Dockerfile              # Multi-stage (dev=Vite, prod=nginx)
│   ├── nginx/nginx.conf        # Reverse proxy en mode prod
│   ├── package.json
│   └── src/                    # App React
├── db/
│   └── init.sql                # Script initialisation PostgreSQL
├── secrets/
│   └── db_password.txt.example # Template secret DB
├── compose.yaml                # Config développement
├── compose.prod.yaml           # Override production locale
├── .env.example                # Template variables
└── README.md
```

## Architecture réseau

**Mode développement** :
- Frontend (Vite) : `http://localhost:5173`
- Backend (API) : `http://localhost:3001`
- DB : accessible uniquement depuis le backend

**Mode production locale** :
- Point d'entrée unique : `http://localhost` (port 80)
- Nginx sert le frontend et proxy `/api/*` vers le backend
- Backend non exposé sur l'hôte

**Réseaux** :
- `front_net` : frontend + backend (communication API)
- `back_net` (internal) : backend + DB (isolation sécurité)

La DB est isolée sur le réseau interne, elle n'est pas accessible depuis le frontend ou l'extérieur.

## Choix techniques

### Dockerfiles multi-stage

**Backend** :
- Target `dev` : avec nodemon pour le hot-reload
- Target `prod` : minimal, sans devDependencies

**Frontend** :
- Target `dev` : Vite en mode dev
- Target `prod` : build statique servi par nginx (non-root)

### Secrets

Utilisation de Docker Compose secrets pour éviter les mots de passe en clair :
- `POSTGRES_PASSWORD_FILE` : lu depuis `/run/secrets/db_password`
- Le fichier `secrets/db_password.txt` n'est pas commité (`.gitignore`)
- Un exemple est fourni : `secrets/db_password.txt.example`

### Volumes

Volume nommé `db-data` pour persister les données PostgreSQL même après `docker compose down`.

### Healthchecks

Tous les services ont des healthchecks. Les dépendances utilisent `condition: service_healthy` pour éviter les erreurs de connexion au démarrage.

## Installation

### 1. Cloner le repository

```bash
git clone https://github.com/Rowliffe/Docker.git
cd Docker/Exam_docker_V6
```

### 2. Créer la configuration locale

**Créer le secret DB** (non commité, utilisé par Docker Compose secrets) :
```bash
cp secrets/db_password.txt.example secrets/db_password.txt
```

**Créer le fichier .env** (non commité) :
```bash
cp .env.example .env
```

> Le `.env` contient uniquement de la config (ports, noms), pas de secrets. Le mot de passe DB est lu depuis `secrets/db_password.txt`.

### 3. (Optionnel) Personnaliser les ports

Éditer `.env` si les ports par défaut sont déjà utilisés :
```bash
FRONTEND_PORT=5173
BACKEND_PORT=3001
POSTGRES_USER=postgres
POSTGRES_DB=evaluation
```

## Lancement en mode développement

## Lancement en mode développement

Démarrer tous les services avec hot-reload :

```bash
docker compose -f compose.yaml up --build
```

**Services disponibles** :
- Frontend (Vite) : http://localhost:5173
- Backend (API) : http://localhost:3001
- DB : accessible uniquement depuis le backend

**Vérification rapide** :
```bash
curl http://localhost:3001/health
# Réponse : {"status":"ok"}

curl http://localhost:3001/api/instruction
# Réponse : {"id":1,"message":"...","created_at":"..."}
```

**Arrêter** :
```bash
docker compose -f compose.yaml down
```

## Lancement en mode production locale

Démarrer avec les images optimisées (targets prod) :

```bash
docker compose -f compose.yaml -f compose.prod.yaml up --build
```

**Point d'entrée unique** :
- Tout passe par nginx : http://localhost (port 80)
- API accessible via : http://localhost/api/instruction
- Backend non exposé directement (sécurité)

**Vérification** :
```bash
curl http://localhost/api/instruction
# Réponse identique, preuve que nginx proxie correctement
```

**Arrêter** :
```bash
docker compose -f compose.yaml -f compose.prod.yaml down
```

## Tests

### Test 1 : Healthcheck backend

```bash
curl http://localhost:3001/health
```

Réponse attendue :
```json
{"status":"ok"}
```

### Test 2 : API + connexion DB

```bash
curl http://localhost:3001/api/instruction
```

Réponse attendue :
```json
{
  "id": 1,
  "message": "Réalise le docker-compose et branche le front sur le back. Bonne chance !",
  "created_at": "2025-12-20T17:25:35.078Z"
}
```

### Test 3 : Point d'entrée unique (mode prod)

```bash
curl http://localhost/api/instruction
```

Même réponse que test 2.

### Test 4 : Frontend

Ouvrir dans un navigateur :
- Mode dev : http://localhost:5173
- Mode prod : http://localhost

L'application React doit afficher le message récupéré depuis l'API.

## Test de persistance (volume)

**Objectif** : prouver que les données survivent au redémarrage.

### 1. Insérer une donnée

```bash
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "INSERT INTO instructions(message) VALUES ('test persistance');"
```

Sortie :
```
INSERT 0 1
```

### 2. Redémarrer la DB

```bash
docker compose -f compose.yaml restart db
```

### 3. Vérifier que la donnée est toujours là

```bash
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "SELECT message FROM instructions ORDER BY id DESC LIMIT 1;"
```

Sortie :
```
     message
-----------------
 test persistance
(1 row)
```

✅ **Preuve de persistance** : la donnée est toujours là après le restart grâce au volume `db-data`.

## Build multi-architecture (AMD64 + ARM64)

Le projet supporte les deux architectures principales grâce à Docker Buildx.

### Configuration initiale (si pas déjà fait)

```bash
docker buildx create --use --name multiarch-builder
docker buildx inspect --bootstrap
```

### Build multi-arch backend

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target prod \
  -t exam-docker-v6-backend:latest \
  ./backend
```

### Build multi-arch frontend

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target prod \
  --build-arg VITE_API_BASE_URL=. \
  -t exam-docker-v6-frontend:latest \
  ./frontend
```

## Registry & Stratégie de versioning

### Choix du registry

**GitHub Container Registry (GHCR)** : `ghcr.io/rowliffe/exam-docker-v6`

Pourquoi GHCR ?
- Gratuit
- Intégré à GitHub
- Support multi-arch

### Convention de tags

Format : `ghcr.io/rowliffe/exam-docker-v6-<service>:<tag>`

**Tags utilisés** :
- `latest` : version stable (branche main)
- `v1.0.0`, `v1.1.0` : versions sémantiques
- `sha-<commit>` : tag immuable basé sur le commit Git
- `dev` : build automatique (CI/CD)

### Exemple : push vers GHCR

**1. Authentification** :
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

**2. Build + push backend** :
```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/rowliffe/exam-docker-v6-backend:v1.0.0 \
  --tag ghcr.io/rowliffe/exam-docker-v6-backend:latest \
  --push \
  ./backend
```

**3. Build + push frontend** :
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

**4. Vérifier le manifest multi-arch** :
```bash
docker buildx imagetools inspect ghcr.io/rowliffe/exam-docker-v6-backend:v1.0.0
```

Sortie attendue :
```
Name:      ghcr.io/rowliffe/exam-docker-v6-backend:v1.0.0
MediaType: application/vnd.docker.distribution.manifest.list.v2+json

Manifests:
  Platform:  linux/amd64
  Platform:  linux/arm64
```

## Optimisations

### Dockerfiles

- **Multi-stage builds** : séparation deps / build / runtime
- **Cache Docker** : `COPY package*.json` avant `COPY . .`
- **.dockerignore** : exclut `node_modules`, `.env`, `dist`
- **Layers** : commandes regroupées pour réduire la taille

### Sécurité

- **Non-root** : tous les conteneurs tournent avec un user non-root
- **Secrets Compose** : pas de mots de passe en clair
- **Réseau interne** : DB isolée sur `back_net` (flag `internal: true`)
- **Images Alpine** : surface d'attaque réduite

### Fiabilité

- **Healthchecks** : `condition: service_healthy` pour les dépendances
- **Volumes nommés** : persistance DB garantie
- **Dépendances explicites** : ordre de démarrage géré par Compose

## Troubleshooting

### Problème : secret manquant

**Erreur** :
```
Error: secret "db_password": file "./secrets/db_password.txt" not found
```

**Solution** :
```bash
cp secrets/db_password.txt.example secrets/db_password.txt
```

### Problème : port 80 déjà utilisé

**Erreur** :
```
Error: bind 0.0.0.0:80: address already in use
```

**Solution** : changer le port dans `compose.prod.yaml` :
```yaml
ports:
  - "8080:8080"  # au lieu de "80:8080"
```

Puis accéder à http://localhost:8080

### Problème : conteneurs unhealthy

**Erreur** :
```bash
docker compose ps
# backend-1  Up 30s (unhealthy)
```

**Diagnostic** :
```bash
docker compose -f compose.yaml logs backend
```

**Causes fréquentes** :
- Mauvaise DATABASE_URL → vérifier `secrets/db_password.txt`
- DB pas prête → attendre 10-20s
- Port déjà pris → changer BACKEND_PORT dans `.env`

### Problème : Docker Desktop non démarré

**Erreur** :
```
Error: open //./pipe/dockerDesktopLinuxEngine: Le fichier spécifié est introuvable
```

**Solution** : lancer Docker Desktop et attendre qu'il soit "Running".

### Problème : erreur YAML `!override` / `!reset`

**Erreur** :
```
Error: yaml: unmarshal errors: line X: cannot unmarshal !!str `!override`
```

**Cause** : Docker Compose trop ancien (< v2.20)

**Solution** : mettre à jour Docker Compose ou remplacer par une approche `profiles`.

### Commandes utiles

**Voir les logs** :
```bash
docker compose -f compose.yaml logs -f
docker compose -f compose.yaml logs -f backend
```

**Rebuild sans cache** :
```bash
docker compose -f compose.yaml build --no-cache
docker compose -f compose.yaml up --force-recreate
```

**Voir l'état des conteneurs** :
```bash
docker compose -f compose.yaml ps
```

## Base de données

### Table `instructions`

| Colonne       | Type         | Description                    |
|---------------|--------------|--------------------------------|
| `id`          | SERIAL       | Clé primaire auto-incrémentée |
| `message`     | TEXT         | Message de l'instruction       |
| `created_at`  | TIMESTAMPTZ  | Date de création (UTC)         |

### Exemple de requête

```bash
docker compose -f compose.yaml exec db psql -U postgres -d evaluation -c "SELECT * FROM instructions;"
```

## API

### GET /health

Healthcheck endpoint.

Réponse :
```json
{"status":"ok"}
```

### GET /api/instruction

Récupère la première instruction de la DB.

Réponse (200) :
```json
{
  "id": 1,
  "message": "Réalise le docker-compose et branche le front sur le back. Bonne chance !",
  "created_at": "2025-12-20T17:25:35.078Z"
}
```

Réponse (404) :
```json
{"error": "No instruction found"}
```

Réponse (500) :
```json
{"error": "Database error"}
```

## Références

- **Guide d'évaluation** : projet-final.pdf (Module Docker/Conteneurisation, Jérémy Marodon, 2025)
- **Docker Compose** : https://docs.docker.com/compose/
- **Buildx** : https://docs.docker.com/buildx/working-with-buildx/
- **GHCR** : https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry

---

**Repository** : https://github.com/Rowliffe/Docker  
**Date limite** : 23 décembre 2025, 23h59

