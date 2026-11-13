#!/usr/bin/env bash
# Starting-composition balance (on demand): every pair of CreatureDB.PACKS
# plays full AI-vs-AI duels (training/arena.gd), both sides on the same level
# (Archmage by default). Each seed is played with the sides swapped.
# Usage:
#   training/pack_matrix.sh [duels per pair] [workers] [seed] [level] [packs json override]
# The optional override is a JSON array of {"forms": [...], "bonus_gold": n}
# replacing CreatureDB.PACKS for the run, to try values without editing the data.
# Prints each pack's score (win = 1, draw = 0.5) against all the others, then
# the full matrix (row pack's score against the column pack).
# FIELD=n (environment) scores every pack only against packs 0..n-1, so extra
# candidate variants appended after them can be compared on the same field.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-$USERPROFILE/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
duels="${1:-40}"; workers="${2:-22}"; seed="${3:-1}"; level="${4:-2}"; packs="${5:-}"
count="$("$godot" --headless --audio-driver Dummy --path "$here" res://training/arena.tscn -- --no-sound --count-packs "--packs=$packs" 2>/dev/null | grep '^PACKS' | awk '{print $2}')"
tmp="$(mktemp -d)"
jobs="$tmp/jobs.txt"
for ((i = 0; i < count; i++)); do
	for ((j = i + 1; j < count; j++)); do
		echo "$i $j" >> "$jobs"
	done
done
export godot here duels seed level packs tmp
xargs -P "$workers" -L 1 bash -c '
	i=$0; j=$1
	out=$(timeout 900 "$godot" --headless --audio-driver Dummy --path "$here" res://training/arena.tscn -- --no-sound \
		"--a={\"level\":$level,\"profile\":{\"pack\":$i}}" "--b={\"level\":$level,\"profile\":{\"pack\":$j}}" \
		"--duels=$duels" "--seed=$((seed * 1000 + i * 37 + j))" "--packs=$packs" 2>&1 | grep "^RESULT\|SCRIPT ERROR" | head -1)
	echo "$i $j $out" > "$tmp/$i-$j.txt"
' < "$jobs"

cat "$tmp"/*-*.txt | awk -v n="$count" -v field="${FIELD:-$count}" '
{
	i = $1; j = $2
	if ($3 != "RESULT") { print "error on pair " i " " j ": " $0; next }
	split($4, a, "="); split($5, b, "="); split($6, d, "=")
	games = a[2] + b[2] + d[2]
	si = a[2] + 0.5 * d[2]; sj = b[2] + 0.5 * d[2]
	score[i, j] = si / games; score[j, i] = sj / games
	if (j < field) { tot[i] += si; g[i] += games }
	if (i < field) { tot[j] += sj; g[j] += games }
	draws += d[2]; all += games
}
END {
	printf "pack  score   (n per pack, %d duels in all, %.1f%% draws)\n", all, 100 * draws / all
	for (k = 0; k < n; k++) printf "%4d  %5.1f%%  %d\n", k, 100 * tot[k] / g[k], g[k]
	printf "\nmatrix (row vs column, %%)\n     "
	for (k = 0; k < n; k++) printf "%4d", k
	printf "\n"
	for (r = 0; r < n; r++) {
		printf "%4d ", r
		for (c = 0; c < n; c++) printf (r == c ? "   -" : "%4.0f"), 100 * score[r, c]
		printf "\n"
	}
}'
rm -rf "$tmp"
