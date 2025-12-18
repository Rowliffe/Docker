FROM node:18-alpine

WORKDIR /app

# Install dependencies (production)
COPY package*.json ./
RUN npm ci --production

# Copy source
COPY . .

EXPOSE 3001

CMD ["npm", "start"]
