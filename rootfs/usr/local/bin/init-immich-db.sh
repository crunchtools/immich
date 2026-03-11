#!/bin/bash
set -e

until pg_isready -U postgres > /dev/null 2>&1; do
  sleep 1
done

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'immich'" | grep -q 1 || \
  sudo -u postgres createdb immich

sudo -u postgres psql -tc "SELECT 1 FROM pg_user WHERE usename = 'immich'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER immich WITH PASSWORD 'immich';"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE immich TO immich;"
sudo -u postgres psql -d immich -c "GRANT ALL ON SCHEMA public TO immich;"
sudo -u postgres psql -d immich -c "ALTER DATABASE immich OWNER TO immich;"

sudo -u postgres psql -d immich -c "CREATE EXTENSION IF NOT EXISTS vector;"
sudo -u postgres psql -d immich -c "CREATE EXTENSION IF NOT EXISTS cube;"
sudo -u postgres psql -d immich -c "CREATE EXTENSION IF NOT EXISTS earthdistance;"
sudo -u postgres psql -d immich -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
sudo -u postgres psql -d immich -c "CREATE EXTENSION IF NOT EXISTS unaccent;"

echo "Immich database initialized with all extensions"
