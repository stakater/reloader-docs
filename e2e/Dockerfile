# Stage 1: Install Playwright and Chromium
FROM node:24-bookworm AS playwright-setup

WORKDIR /e2e

# Copy package files
COPY package.json yarn.lock* ./

# Install dependencies
RUN yarn install --frozen-lockfile || yarn install

# Install only Chromium browser
RUN npx playwright install --with-deps chromium

# Copy tests
COPY src ./src
COPY playwright.config.ts ./

# Set CI env for Playwright
ENV CI=true

# Run Playwright tests
CMD ["yarn", "start"]
