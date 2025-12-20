FROM node:18-alpine AS base
WORKDIR /app

# Optimisation cache
COPY package*.json ./

FROM base AS deps
RUN npm ci

FROM node:18-alpine AS dev
WORKDIR /app
ENV NODE_ENV=development

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Non-root
RUN chown -R node:node /app
USER node

EXPOSE 5173
HEALTHCHECK --interval=5s --timeout=3s --retries=20 CMD wget -qO- http://localhost:5173/ > /dev/null || exit 1
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]

FROM base AS builder
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM nginx:stable-alpine AS prod
# Outils pour HEALTHCHECK
RUN apk add --no-cache curl

COPY --from=builder /app/dist /usr/share/nginx/html
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf

# Non-root : nginx écoute sur 8080 (voir nginx.conf)
RUN chown -R nginx:nginx /usr/share/nginx/html \
  && mkdir -p /var/cache/nginx /var/run \
  && chown -R nginx:nginx /var/cache/nginx /var/run
USER nginx

EXPOSE 8080
HEALTHCHECK --interval=5s --timeout=3s --retries=20 CMD curl -fsS http://localhost:8080/ > /dev/null || exit 1
CMD ["nginx", "-g", "daemon off;"]
