"""Search AI profiles through complete, mirrored Godot duels."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from itertools import combinations
import json
from pathlib import Path
import shutil
import subprocess


PROJECT = Path(__file__).resolve().parents[1]
SHOP = {
    "mages": dict(fireball_value=32, blizzard_value=32, star_ability_scaling=1.0,
                  price_weight=0.18),
    "merges": dict(duplicate_value=24, promotion_value=52, rerolls=4,
                   reroll_reserve=1, replacement_margin=1.25),
    "tempo": dict(price_weight=0.55, rerolls=1, reroll_reserve=3,
                  upgrade_field=6, upgrade_gold=9),
    "recharge": dict(upgrade_field=4, upgrade_gold=5),
    "spread": dict(spread_front=True),
}
CAST = {
    "carry": dict(target_power_weight=0.9, low_health_bonus=0.12, ally_cast_bias=0.1),
    "interrupt": dict(interrupt_value=1.1, stun_value=0.16, cast_threshold=0.22),
    "pressure": dict(cast_threshold=0.06, full_cast_threshold=0.0, stun_value=0.18),
    "conserve": dict(cast_threshold=0.32, full_cast_threshold=0.12),
    "heal": dict(low_health_bonus=0.55, ally_cast_bias=0.07),
}


def play(godot, out, stage, profiles, matchups, seeds, workers):
    pairs = list(matchups)
    jobs = [
        {"id": f"{a}/{b}", "a": profiles[a], "b": profiles[b], "seed": seed}
        for seed in seeds for a, b in pairs
    ]
    batches = [jobs[index::workers] for index in range(min(workers, len(jobs)))]
    stage_dir = out / stage
    stage_dir.mkdir()

    def run_batch(batch):
        index, batch_jobs = batch
        job_file = stage_dir / f"{index}.jobs.json"
        results_file = stage_dir / f"{index}.results.jsonl"
        job_file.write_text(json.dumps(batch_jobs), encoding="utf-8")
        command = [
            godot, "--headless", "--audio-driver", "Dummy", "--path", str(PROJECT),
            "--log-file", str(stage_dir / f"{index}.godot.log"),
            "res://training/self_play.tscn", "--", "--no-sound",
            str(job_file), str(results_file),
        ]
        result = subprocess.run(command, capture_output=True, text=True, timeout=1800)
        if result.returncode or "ERROR:" in result.stderr:
            raise RuntimeError(f"{stage} worker {index}: {result.stdout}\n{result.stderr}")
        rows = [json.loads(line) for line in results_file.read_text(encoding="utf-8").splitlines()]
        if len(rows) != 2 * len(batch_jobs):
            raise RuntimeError(f"{stage} worker {index} returned {len(rows)} results")
        print(f"{stage}: worker {index + 1}/{len(batches)} finished ({len(rows)} duels)", flush=True)
        return rows

    print(f"{stage}: {2 * len(jobs)} duels", flush=True)
    scores = {f"{a}/{b}": Counter() for a, b in pairs}
    with ThreadPoolExecutor(max_workers=len(batches)) as pool:
        for rows in pool.map(run_batch, enumerate(batches)):
            for row in rows:
                scores[row["id"]][int(row["winner"])] += 1
    summary = {
        pair: {"wins": counts[0], "losses": counts[1], "draws": counts[-1]}
        for pair, counts in scores.items()
    }
    (stage_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary), flush=True)
    return scores


def points(counts, side=0):
    return counts[side] + 0.5 * counts[-1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot"))
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--seed", type=int, default=84000)
    args = parser.parse_args()
    if not args.godot or args.workers < 1 or not 0 <= args.seed < 2**31:
        parser.error("provide --godot, a positive worker count and a seed from 0 to 2^31-1")
    out = PROJECT / ".godot" / "self-play" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    out.mkdir(parents=True)
    print(f"Results: {out}", flush=True)
    profiles = {"baseline": {}, **SHOP, **CAST}
    seed = args.seed
    screen = play(args.godot, out, "screen", profiles,
                  [(name, "baseline") for name in (*SHOP, *CAST)], range(seed, seed + 12),
                  args.workers)
    best_shop = sorted(SHOP, key=lambda name: points(screen[f"{name}/baseline"]), reverse=True)[:2]
    best_cast = sorted(CAST, key=lambda name: points(screen[f"{name}/baseline"]), reverse=True)[:2]
    for shop in best_shop:
        for cast in best_cast:
            profiles[f"{shop}+{cast}"] = {**SHOP[shop], **CAST[cast]}
    finalists = ["baseline", *best_shop, *best_cast, *(name for name in profiles if "+" in name)]
    league = play(args.godot, out, "league", profiles, combinations(finalists, 2),
                  range(seed + 1000, seed + 1008), args.workers)
    totals = Counter()
    for pair, counts in league.items():
        a, b = pair.split("/")
        totals[a] += points(counts)
        totals[b] += points(counts, 1)
    challengers = sorted(finalists[1:], key=totals.get, reverse=True)
    champion = challengers[0]
    opponents = ["baseline", *challengers[1:4]]
    validation = play(args.godot, out, "validation", profiles,
                      [(champion, name) for name in opponents],
                      range(seed + 2000, seed + 2050), args.workers)
    baseline = validation[f"{champion}/baseline"]
    other = sum(points(validation[f"{champion}/{name}"]) for name in opponents[1:])
    selected = champion if points(baseline) > 55 and other > 150 else "baseline"
    report = {
        "seed": seed, "league_points": dict(totals), "challenger": champion,
        "selected": selected, "profile": profiles[selected],
        "validation": {pair: dict(counts) for pair, counts in validation.items()},
    }
    (out / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    main()
