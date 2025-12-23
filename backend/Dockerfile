FROM node:18-alpine AS base
WORKDIR /app

# Optimisation cache
COPY package*.json ./

FROM base AS deps-dev
RUN npm ci

FROM base AS deps-prod
RUN npm ci --omit=dev

FROM node:18-alpine AS dev
WORKDIR /app
ENV NODE_ENV=development

COPY --from=deps-dev /app/node_modules ./node_modules
COPY . .

# Ensure bash is installed and fix CRLF if present
RUN apk add --no-cache bash && sed -i 's/\r$//' /app/docker-entrypoint.sh

# Non-root
RUN chown -R node:node /app
USER node

EXPOSE 3001
HEALTHCHECK --interval=5s --timeout=3s --retries=20 CMD wget -qO- http://localhost:3001/health > /dev/null || exit 1

ENTRYPOINT ["/bin/bash", "/app/docker-entrypoint.sh"]
CMD ["npm", "run", "dev"]

FROM node:18-alpine AS prod
WORKDIR /app
ENV NODE_ENV=production

COPY --from=deps-prod /app/node_modules ./node_modules
COPY . .

# Ensure bash is installed and fix CRLF if present
RUN apk add --no-cache bash && sed -i 's/\r$//' /app/docker-entrypoint.sh

# Non-root
RUN chown -R node:node /app
USER node

EXPOSE 3001
HEALTHCHECK --interval=5s --timeout=3s --retries=20 CMD wget -qO- http://localhost:3001/health > /dev/null || exit 1

ENTRYPOINT ["/bin/bash", "/app/docker-entrypoint.sh"]
CMD ["npm", "start"]
