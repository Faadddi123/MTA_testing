#!/usr/bin/env bash
# Run once after clone or when [gameplay] stock resources are present.
# eXo meta + mtaserver expect resource names "reload" and "parachute" at the
# resources/ root; stock MTA ships them under mods/deathmatch/[gameplay]/.
set -euo pipefail
RES="$(cd "$(dirname "$0")/../mods/deathmatch/resources" && pwd)"
cd "$RES"
ln -sfn ../[gameplay]/reload reload
ln -sfn ../[gameplay]/parachute parachute
echo "Symlinks OK: reload, parachute -> ../[gameplay]/..."
