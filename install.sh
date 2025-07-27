#!/bin/bash
set -e

# Working directory
cd /home/container

INSTALL_MARKER="./musicbrainz-docker/local/.db_initialized"

# If marker file indicating installation exists, skip install and run startup
if [[ -f "$INSTALL_MARKER" ]]; then
  echo "Installation already completed. Switching to startup script..."
  # Assuming start.sh is in /home/container/musicbrainz-docker
  bash ./musicbrainz-docker/start.sh
  exit 0
fi

# Proceed with installation if no marker found

# Clone the MusicBrainz Docker repo if not present, checkout the specified branch
if [ ! -d "musicbrainz-docker" ]; then
  echo "Cloning MusicBrainz Docker repository (branch: ${MB_GIT_BRANCH:-v-2025-06-23.0})..."
  git clone --depth=1 --branch "${MB_GIT_BRANCH:-v-2025-06-23.0}" https://github.com/metabrainz/musicbrainz-docker.git
else
  echo "musicbrainz-docker directory found, updating branch ${MB_GIT_BRANCH:-v-2025-06-23.0}..."
  cd musicbrainz-docker
  git fetch origin "${MB_GIT_BRANCH:-v-2025-06-23.0}"
  git checkout "${MB_GIT_BRANCH:-v-2025-06-23.0}"
  git pull origin "${MB_GIT_BRANCH:-v-2025-06-23.0}"
  cd ..
fi

cd musicbrainz-docker

# Export environment variables for docker-compose (versions)
export MB_SOLR_VERSION="${MB_SOLR_VERSION:-4.1.0}"
export POSTGRES_VERSION="${POSTGRES_VERSION:-16}"

echo "Building Docker images with Solr ${MB_SOLR_VERSION} and PostgreSQL ${POSTGRES_VERSION}..."
docker compose build

echo "Creating database and importing full data dumps..."
docker compose run --rm musicbrainz createdb.sh -fetch

if [[ "${BUILD_MATERIALIZED_TABLES:-0}" == "1" ]]; then
  echo "Building materialized tables..."
  docker compose run --rm musicbrainz bash -c 'carton exec -- ./admin/BuildMaterializedTables --database=MAINTENANCE all'
else
  echo "Skipping materialized tables build."
fi

# Create marker to indicate installation done
touch ../local/.db_initialized

echo "Installation complete."

# Optionally start the server automatically after install
bash ./start.sh
