#!/bin/bash
set -e

# 1. Clone the MusicBrainz Docker repository
if [ ! -d "musicbrainz-docker" ]; then
  git clone --depth=1 https://github.com/metabrainz/musicbrainz-docker.git
fi
cd musicbrainz-docker

# 2. Build Docker images
docker compose build

# 3. Create the database and import full data dumps
docker compose run --rm musicbrainz createdb.sh -fetch

# 4. Build materialized tables
if [[ "$BUILD_MATERIALIZED_TABLES" == "1" ]]; then
  echo "Building Materialized Tables..."
  docker compose run --rm musicbrainz bash -c 'carton exec -- ./admin/BuildMaterializedTables --database=MAINTENANCE all'
else
  echo "Skipping build of materialized tables."
fi
