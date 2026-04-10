#!/usr/bin/env bash
# Run once after clone or when [gameplay] stock resources are present.
# eXo meta + mtaserver expect resource names "reload" and "parachute" at the
# resources/ root; stock MTA ships them under mods/deathmatch/[gameplay]/.
# emerlights: mods/deathmatch/resources/exo/deps/emerlights — remove stale resources/emerlights if upgrading.
set -euo pipefail
RES="$(cd "$(dirname "$0")/../mods/deathmatch/resources" && pwd)"
cd "$RES"
if [[ -e emerlights && ! -L emerlights ]]; then
	echo "Removing duplicate resources/emerlights (use exo/deps/emerlights only)." >&2
	rm -rf emerlights
fi
if [[ -d '[vrp]' ]]; then
	echo "Removing obsolete resources/[vrp] (gamemode is now resources/exo/)." >&2
	rm -rf '[vrp]'
fi
ln -sfn ../[gameplay]/reload reload
ln -sfn ../[gameplay]/parachute parachute
echo "Symlinks OK: reload, parachute -> ../[gameplay]/..."
