#!/bin/sh
# Versão simplificada do script de entrypoint para o Easypanel

set -e

# Remove um arquivo de PID do servidor que pode ter sobrado de uma execução anterior
if [ -f /app/tmp/pids/server.pid ]; then
  rm /app/tmp/pids/server.pid
fi

# Executa as migrações do banco de dados
# É uma boa prática rodar isso toda vez que o container inicia
# para garantir que o schema do banco de dados está atualizado.
bundle exec rake db:migrate

# Executa o comando principal do container (o CMD do Dockerfile)
exec "$@"
