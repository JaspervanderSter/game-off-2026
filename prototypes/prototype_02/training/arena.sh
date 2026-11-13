#!/usr/bin/env bash
# Parallel strategy arena (training/arena.gd). Usage:
#   training/arena.sh '<side A json>' '<side B json>' [workers] [duels per worker] [seed]
# Prints the summed result: A wins, B wins, draws, A win rate and averages.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-$USERPROFILE/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
a="$1"; b="$2"; workers="${3:-22}"; duels="${4:-20}"; seed="${5:-1}"
tmp="$(mktemp -d)"
for ((w = 0; w < workers; w++)); do
	timeout 900 "$godot" --headless --audio-driver Dummy --path "$here" res://training/arena.tscn -- --no-sound \
		"--a=$a" "--b=$b" "--duels=$duels" "--seed=$((seed * 1000 + w))" > "$tmp/$w.txt" 2>&1 &
done
wait

grep -h "SCRIPT ERROR\|ERROR:" "$tmp"/*.txt | sort | uniq -c | head -5 || true
grep -h "^RESULT" "$tmp"/*.txt | awk '
{ n++; for (i = 2; i <= NF; i++) { split($i, kv, "="); sum[kv[1]] += kv[2]; if (n == 1) order[i] = kv[1]; last = NF } }
END {
	if (n == 0) { print "no results"; exit 1 }
	total = sum["a"] + sum["b"] + sum["draws"]
	printf "A %d  B %d  draws %d  | A win %.1f%%  (n=%d)\n", sum["a"], sum["b"], sum["draws"], 100 * (sum["a"] + 0.5 * sum["draws"]) / total, total
	for (i = 5; i <= last; i++) printf "%s=%.2f ", order[i], sum[order[i]] / n
	printf "\n"
}'
rm -rf "$tmp"
