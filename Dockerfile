# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies for better-sqlite3
RUN apk add --no-cache python3 make g++ sqlite

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source files
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM node:20-alpine

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache sqlite

# Copy built application
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/schema ./schema
COPY --from=builder /app/scripts ./scripts

# Create data directory
RUN mkdir -p /data

# Set environment variables
ENV NODE_ENV=production
ENV DATABASE_PATH=/data/pbnj.db
ENV HOST=0.0.0.0
ENV PORT=4321

# Expose the application port
EXPOSE 4321

# Create volume for persistent data
VOLUME ["/data"]

# Initialize database and start server
CMD ["sh", "-c", "node scripts/init-db.mjs && node dist/server/entry.mjs"]
