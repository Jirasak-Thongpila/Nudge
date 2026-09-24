FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

# Copy application source and migrations
COPY . .

# Set production defaults
ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

EXPOSE 3000

# Push DB schema migrations if DATABASE_URL is set, then launch backend
CMD ["sh", "-c", "if [ -n \"$DATABASE_URL\" ]; then bun run db:push; fi && bun run start"]
