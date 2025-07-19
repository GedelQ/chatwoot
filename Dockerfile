# Dockerfile para Chatwoot em Produção

# --- Estágio 1: Builder de Assets (Frontend) ---
# Usa uma imagem Node.js para instalar dependências e compilar os assets.
FROM node:18-slim as builder-assets

# Instala o pnpm, que é o gerenciador de pacotes usado pelo Chatwoot
RUN npm install -g pnpm

WORKDIR /app

# Copia os arquivos de dependência e instala para aproveitar o cache do Docker
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --prod

# Copia o restante do código da aplicação
COPY . .

# Compila os assets do frontend com Vite
# O comando 'bundle exec' garante que estamos usando a versão correta do vite-rails
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && bundle exec vite:build


# --- Estágio 2: Builder de Gems (Backend) ---
# Usa a imagem oficial do Ruby para instalar as gems
FROM ruby:3.4.4-slim as builder-gems

WORKDIR /app

# Instala dependências de sistema necessárias para compilar gems (ex: pg, nokogiri)
RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential libpq-dev

# Copia os arquivos de dependências do Ruby
COPY Gemfile Gemfile.lock ./

# Configura o Bundler para não instalar gems de desenvolvimento e teste
RUN bundle config set --local without 'development test'

# Instala as gems
RUN bundle install --jobs $(nproc) --retry 3


# --- Estágio 3: Imagem Final de Produção ---
# Começa com uma imagem Ruby limpa e leve
FROM ruby:3.4.4-slim

WORKDIR /app

# Instala apenas as dependências de sistema necessárias para rodar a aplicação
RUN apt-get update -qq && apt-get install -y --no-install-recommends libpq-dev nodejs curl && rm -rf /var/lib/apt/lists/*

# Copia as gems instaladas do estágio de build de gems
COPY --from=builder-gems /usr/local/bundle /usr/local/bundle

# Copia os assets compilados do estágio de build de assets
COPY --from=builder-assets /app/public /app/public

# Copia o código da aplicação
COPY . .

# Expõe a porta que o Puma (servidor de aplicação) irá usar
EXPOSE 3000

# Define variáveis de ambiente para produção
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true

# Comando para iniciar o servidor de aplicação
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
