# Dockerfile Unificado para Chatwoot em Produção (Easypanel) - v2

# --- Estágio 1: Base e Dependências ---
FROM ruby:3.4.4-alpine3.21 as base

# Instala dependências de sistema essenciais, incluindo Node.js e npm
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm \
    postgresql-dev \
    tzdata \
    vips

# Instala o pnpm, o gerenciador de pacotes do Node.js usado pelo Chatwoot
RUN npm install -g pnpm

WORKDIR /app

# --- Estágio 2: Builder de Gems ---
# Este estágio foca em instalar as dependências do Ruby (gems)
FROM base as builder-gems

# Copia os arquivos de definição de dependências
COPY Gemfile Gemfile.lock ./

# Instala as gems, excluindo as de desenvolvimento e teste para produção
RUN bundle config set --local without 'development test' && \
    bundle install --jobs $(nproc) --retry 3

# --- Estágio 3: Builder de Assets ---
# Este estágio foca em instalar as dependências do Node.js e compilar os assets
FROM base as builder-assets

# Copia os arquivos de definição de dependências do frontend
COPY package.json pnpm-lock.yaml ./

# Instala as dependências do Node.js para produção
RUN pnpm install --prod

# Copia o restante do código da aplicação
COPY . .

# Pré-compila os assets para produção
# A variável SECRET_KEY_BASE é necessária para o processo de compilação
RUN SECRET_KEY_BASE=dummy bundle exec rake assets:precompile

# --- Estágio 4: Imagem Final ---
# Este é o estágio final que irá gerar a imagem de produção
FROM base

# Copia as gems instaladas do estágio builder-gems
COPY --from=builder-gems /usr/local/bundle /usr/local/bundle

# Copia os assets compilados do estágio builder-assets
COPY --from=builder-assets /app/public /app/public

# Copia o código da aplicação
COPY . .

# Gera um arquivo com o hash do commit para versionamento interno do Chatwoot
RUN git rev-parse HEAD > .git_sha

# Limpa arquivos desnecessários para reduzir o tamanho da imagem
RUN rm -rf .git .github .vscode spec node_modules tmp/cache vendor/bundle

# Copia o novo script de entrypoint e o torna executável
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

# Expõe a porta do servidor
EXPOSE 3000

# Comando padrão para iniciar o servidor Puma
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
