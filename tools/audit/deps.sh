#!/usr/bin/env bash
# Dependency vulnerability scan (MASVS-CODE-3, docs/security/masvs-l1.md F-7).
# Run before every release and after dependency bumps. CI is parked, so this is
# a local script; it needs network access (npm registry, api.osv.dev, pub.dev).
#
#   bash tools/audit/deps.sh            # scan everything, print a summary
#   bash tools/audit/deps.sh --no-outdated   # skip the (slow, informational) pub outdated step
#
# What it checks
#   1. pnpm audit --prod        server/aura-api, apps/admin (npm advisories; production deps only)
#   2. Dart / Flutter advisories for pubspec.lock (the pub workspace: apps/mobile + packages/aura_domain):
#        osv-scanner when installed (brew install osv-scanner), else a direct OSV.dev batch query of every
#        hosted package@version in pubspec.lock (the "Pub" ecosystem = GitHub advisories, as pub.dev shows them)
#   3. flutter pub outdated     informational: what's behind (not a failure)
#
# Exit status: 0 = no known vulnerabilities; 1 = at least one advisory (details above the summary);
# 2 = a check could not run (offline, tool missing) and nothing was found by the others.
# Sends only package names and versions to the registries / OSV; nothing from the app or its users.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDATED=1
[ "${1:-}" = "--no-outdated" ] && OUTDATED=0

declare -a SUMMARY=()
found=0
errored=0

hr() { printf '\n==== %s ====\n' "$1"; }
record() { SUMMARY+=("$(printf '%-34s %s' "$1" "$2")"); }

# ---- 1. npm (pnpm audit) ------------------------------------------------------
for pkg in server/aura-api apps/admin; do
  hr "pnpm audit --prod: $pkg"
  dir="$ROOT/$pkg"
  if [ ! -f "$dir/pnpm-lock.yaml" ]; then
    echo "no pnpm-lock.yaml, skipped"
    record "$pkg (npm)" "SKIPPED (no lockfile)"
    continue
  fi
  if ! command -v pnpm >/dev/null; then
    echo "pnpm not installed"
    record "$pkg (npm)" "ERROR (pnpm missing)"
    errored=1
    continue
  fi
  json="$(cd "$dir" && pnpm audit --prod --json 2>/dev/null)"
  counts="$(printf '%s' "$json" | node -e '
    let s = "";
    process.stdin.on("data", (d) => (s += d)).on("end", () => {
      try {
        const j = JSON.parse(s);
        const v = (j.metadata && j.metadata.vulnerabilities) || {};
        for (const a of Object.values(j.advisories || {})) {
          const paths = [...new Set(a.findings.flatMap((f) => f.paths))].slice(0, 3).join(", ");
          console.error(`  ${a.severity.padEnd(8)} ${a.module_name} ${a.vulnerable_versions} -> ${a.patched_versions}  ${a.title}  [${paths}]`);
        }
        const total = ["low", "moderate", "high", "critical"].reduce((n, k) => n + (v[k] || 0), 0);
        console.log(`${total} critical=${v.critical || 0} high=${v.high || 0} moderate=${v.moderate || 0} low=${v.low || 0}`);
      } catch {
        console.log("error");
      }
    });')"
  if [ "$counts" = "error" ] || [ -z "$counts" ]; then
    echo "pnpm audit gave no readable answer (offline?)"
    record "$pkg (npm)" "ERROR (no answer)"
    errored=1
  elif [ "${counts%% *}" = "0" ]; then
    echo "no known vulnerabilities"
    record "$pkg (npm)" "OK"
  else
    record "$pkg (npm)" "VULNERABLE (${counts#* })"
    found=1
  fi
done

# ---- 2. Dart / Flutter advisories ----------------------------------------------
hr "Dart advisories: pubspec.lock"
LOCK="$ROOT/pubspec.lock"
if command -v osv-scanner >/dev/null; then
  # osv-scanner exit codes: 0 = clean, 1 = vulnerabilities found, anything
  # else = it couldn't scan. v2 syntax first; the v1 form only when v2 itself
  # failed to run (never after it has already reported findings).
  osv-scanner scan source --lockfile "$LOCK" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
    echo "(osv-scanner v2 syntax failed with $rc; trying the v1 form)"
    osv-scanner --lockfile "$LOCK" 2>&1
    rc=$?
  fi
  case "$rc" in
    0) record "pubspec.lock (osv-scanner)" "OK" ;;
    1) record "pubspec.lock (osv-scanner)" "VULNERABLE (see above)"; found=1 ;;
    *) record "pubspec.lock (osv-scanner)" "ERROR (exit $rc)"; errored=1 ;;
  esac
else
  echo "(osv-scanner not installed: querying api.osv.dev directly)"
  out="$(python3 - "$LOCK" <<'PY'
import json, re, sys, urllib.request

text = open(sys.argv[1], encoding="utf-8").read()
pkgs = []
# Each package block: "  name:\n    dependency: …\n    description: …\n    source: hosted\n    version: \"x\""
for m in re.finditer(r'^  ([a-z0-9_]+):\n((?:    .*\n|      .*\n)+)', text, re.M):
    name, body = m.group(1), m.group(2)
    if "source: hosted" not in body:
        continue
    v = re.search(r'^    version: "([^"]+)"', body, re.M)
    if v:
        pkgs.append((name, v.group(1)))
if not pkgs:
    print("ERROR no hosted packages parsed")
    sys.exit(0)
queries = [{"package": {"name": n, "ecosystem": "Pub"}, "version": v} for n, v in pkgs]
try:
    req = urllib.request.Request(
        "https://api.osv.dev/v1/querybatch",
        data=json.dumps({"queries": queries}).encode(),
        headers={"Content-Type": "application/json"},
    )
    res = json.load(urllib.request.urlopen(req, timeout=30))
except Exception as e:  # offline, proxy, …
    print(f"ERROR osv.dev unreachable ({type(e).__name__})")
    sys.exit(0)
hits = []
for (name, version), r in zip(pkgs, res.get("results", [])):
    for vuln in r.get("vulns") or []:
        hits.append(f"  {name} {version}: {vuln['id']} (https://osv.dev/vulnerability/{vuln['id']})")
print(f"{len(pkgs)} packages checked")
print("\n".join(hits) if hits else "no known vulnerabilities")
print(f"HITS {len(hits)}")
PY
)"
  echo "$out" | grep -v '^HITS '
  hits="$(echo "$out" | sed -n 's/^HITS //p')"
  if echo "$out" | grep -q '^ERROR'; then
    record "pubspec.lock (osv.dev)" "ERROR (see above)"
    errored=1
  elif [ "${hits:-0}" = "0" ]; then
    record "pubspec.lock (osv.dev)" "OK"
  else
    record "pubspec.lock (osv.dev)" "VULNERABLE ($hits advisories)"
    found=1
  fi
fi

# ---- 3. flutter pub outdated (informational) ------------------------------------
if [ "$OUTDATED" = "1" ]; then
  hr "flutter pub outdated (informational)"
  if command -v flutter >/dev/null; then
    (cd "$ROOT/apps/mobile" && flutter pub outdated --no-dev-dependencies --no-transitive 2>&1 | sed -n '/^Showing/,$p' | head -60)
    record "pub outdated" "INFO (review above; not a failure)"
  else
    record "pub outdated" "SKIPPED (flutter missing)"
  fi
fi

# ---- summary ---------------------------------------------------------------------
hr "Summary"
printf '%s\n' "${SUMMARY[@]}"
if [ "$found" = "1" ]; then
  echo "Result: known vulnerabilities found. Update the package (or add a reviewed pnpm override) and re-run."
  exit 1
fi
if [ "$errored" = "1" ]; then
  echo "Result: nothing found, but at least one check could not run."
  exit 2
fi
echo "Result: no known vulnerabilities."
exit 0
