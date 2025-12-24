FROM public.ecr.aws/docker/library/node:22-slim
RUN npm install -g npm@11 --loglevel=error

# Instalando curl
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# Argumento para ambiente
ARG ENVIRONMENT=production
ENV NODE_ENV=$ENVIRONMENT

# Copiar package.json raiz primeiro
COPY package*.json ./
RUN npm install --loglevel=error

# Copiar package.json do client e instalar dependências (incluindo devDependencies para build)
COPY client/package*.json ./client/
RUN cd client && npm install --include=dev --legacy-peer-deps --loglevel=error

# Copiar todos os arquivos
COPY . .

# Build do front-end com Vite baseado no ambiente
RUN cd client && \
    if [ "$ENVIRONMENT" = "staging" ]; then \
        VITE_API_URL=/api npm run build; \
    else \
        VITE_API_URL=/api npm run build; \
    fi

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/api/versao || exit 1

EXPOSE 80

CMD [ "npm", "start" ]
