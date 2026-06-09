#!/usr/bin/env sh
set -eu
: "${MOONSTONE_TOKEN:?Set MOONSTONE_TOKEN to a write:registry API token}"
curl --fail-with-body -H "Authorization: Bearer $MOONSTONE_TOKEN" -F descriptor=@"$(dirname "$0")/package.toml" -F blob=@"$(dirname "$0")/love-importer-0.1.1-any.tar.gz" "${MOONSTONE_PUBLISH_URL:-https://moonstone.sh/api/registry/v0/publish}"
