#!/bin/bash
set -e

# Move to container working directory
cd /home/container

# Clone the specific MusicBrainz branch if not already cloned
if [ ! -d "musicbrainz-docker" ]; then
  echo "Cloning MusicBrainz Docker repository (branch: ${MB_GIT_BRANCH})..."
  git clone --depth=1 --branch "${MB_GIT_BRANCH}" https://github.com/metabrainz/musicbrainz-docker.git
else
  echo "musicbrainz-docker directory already exists, fetching latest changes for branch ${MB_GIT_BRANCH}..."
  cd musicbrainz-docker
  git fetch origin "${MB_GIT_BRANCH}"
  git checkout "${MB_GIT_BRANCH}"
  git pull origin "${MB_GIT_BRANCH}"
  cd ..
fi

cd musicbrainz-docker

# Export versions as environment variables for docker-compose usage
export MB_SOLR_VERSION="${MB_SOLR_VERSION}"
export POSTGRES_VERSION="${POSTGRES_VERSION}"

echo "Building Docker images with Solr version ${MB_SOLR_VERSION} and Postgres version ${POSTGRES_VERSION}..."
docker compose build

echo "Creating database and importing full data dumps..."
docker compose run --rm musicbrainz createdb.sh -fetch

# Conditionally build materialized tables based on BUILD_MATERIALIZED_TABLES variable
if [[ "${BUILD_MATERIALIZED_TABLES:-0}" == "1" ]]; then
  echo "Building materialized tables as requested..."
  docker compose run --rm musicbrainz bash -c 'carton exec -- ./admin/BuildMaterializedTables --database=MAINTENANCE all'
else
  echo "Skipping materialized tables build."
fi

echo "Installation completed."
