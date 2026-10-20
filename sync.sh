#!/bin/sh
# Copy the published data files from a momsite checkout into data/, then rewrite MANIFEST.csv.
# Usage: ./sync.sh /path/to/momsite   (use a checkout of origin/main that matches the live site)
set -eu
SRC="${1:?usage: ./sync.sh /path/to/momsite}"
cd "$(dirname "$0")"

rm -rf data
mkdir -p data/benefits data/reports
# Top-level benefit files only. data/benefits/wic-clinics/ stays out: some state clinic lists bar commercial reuse.
cp "$SRC"/data/benefits/*.json data/benefits/
cp "$SRC"/public/data/benefits/*.csv data/benefits/
cp "$SRC"/public/data/reports/*.csv data/reports/

COMMIT="$(git -C "$SRC" rev-parse --short HEAD)"
python3 - "$COMMIT" <<'PY'
import csv, hashlib, json, os, sys
rows = []
for root, _, files in os.walk("data"):
    for name in sorted(files):
        path = os.path.join(root, name)
        raw = open(path, "rb").read()
        if name.endswith(".json"):
            d = json.loads(raw)
            records, as_of = len(d.get("states", {})), d.get("asOf", "")
        else:
            table = list(csv.DictReader(raw.decode("utf-8").splitlines()))
            records = len(table)
            as_of = ";".join(sorted({r["as_of"] for r in table if r.get("as_of")}))
        rows.append([path, records, as_of, len(raw), hashlib.sha256(raw).hexdigest()])
with open("MANIFEST.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["file", "records", "as_of", "bytes", "sha256"])
    w.writerows(sorted(rows))
with open("data/SOURCE_COMMIT", "w") as f:
    f.write(f"momsite {sys.argv[1]}\n")
PY
echo "Synced from momsite $COMMIT. Review with: git diff --stat"
