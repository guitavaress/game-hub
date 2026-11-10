# O painel do cofre em dois estágios:
# 1) "build": instala os pacotes e compila o React (Vite) para dist/;
# 2) a imagem final só tem o Node, o git e o resultado. Sem node_modules.

FROM node:22.23.4-alpine3.24 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY index.html vite.config.js ./
COPY public ./public
COPY src ./src
RUN npm run build

FROM node:22.23.4-alpine3.24
# git: para a branch e os commits (só leitura).
RUN apk add --no-cache git
WORKDIR /app
ENV NODE_ENV=production PORT=4170 REPO=/repo DOCS=/repo/docs SITE=/app/dist
COPY package.json ./
COPY server ./server
COPY --from=build /app/dist ./dist
USER node
EXPOSE 4170
CMD ["node", "server/index.js"]
