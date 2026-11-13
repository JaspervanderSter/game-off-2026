#!/usr/bin/env bash
# Hill-climb helper: plays each variant (champion profile + one change) against
# the champion. Usage: training/climb.sh '<champion profile json body>' 'label|json fragment' ...
here="$(cd "$(dirname "$0")" && pwd)"
champ="$1"; shift
for v in "$@"; do
	label="${v%%|*}"; frag="${v#*|}"
	printf "%-28s " "$label"
	"$here/arena.sh" "{\"level\":2,\"profile\":{$champ,$frag}${CAST_A:-}}" "{\"level\":2,\"profile\":{$champ}}" "${WORKERS:-22}" "${DUELS:-20}" "${SEED:-7}" | head -1
done
