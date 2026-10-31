#!/bin/sh
# Sandboxed test: does `mvc --history=merge` combine source and destination history?
# Uses a throwaway CLAUDE_CONFIG_DIR and HOME, so your real ~/.claude is never touched.
# Usage: tests/merge-test.sh [--keep]     (--keep leaves the sandbox for inspection)
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
T=$(python3 -c "import os,tempfile;print(os.path.realpath(tempfile.mkdtemp()))")
export HOME=$T/home CLAUDE_CONFIG_DIR=$T/cc
mkdir -p "$HOME" "$T/cc/projects" "$T/old-app" "$T/new-app"
rmdir "$T/new-app"   # mv needs the destination folder to not exist; its history does

enc() { printf %s "$1" | sed 's/[^a-zA-Z0-9]/-/g'; }
SRC_P=$T/cc/projects/$(enc "$T/old-app")
DST_P=$T/cc/projects/$(enc "$T/new-app")
mkdir -p "$SRC_P/memory" "$DST_P"

# Source history: 2 sessions + a memory file. Destination history: 1 session.
printf '{"cwd":"%s","msg":"src session 1"}\n' "$T/old-app" > "$SRC_P/aaaa-1111.jsonl"
printf '{"cwd":"%s","msg":"src session 2"}\n' "$T/old-app" > "$SRC_P/bbbb-2222.jsonl"
echo "source memory" > "$SRC_P/memory/MEMORY.md"
printf '{"cwd":"%s","msg":"dst session"}\n'   "$T/new-app" > "$DST_P/cccc-3333.jsonl"
cat > "$T/cc/.claude.json" <<J
{"projects":{"$T/old-app":{"from":"src","shared":"src"},"$T/new-app":{"shared":"dst"}}}
J

echo "BEFORE"
echo "  source      sessions: $(ls "$SRC_P"/*.jsonl | wc -l | tr -d ' ')"
echo "  destination sessions: $(ls "$DST_P"/*.jsonl | wc -l | tr -d ' ')"
echo
echo "RUN: mvc -v --history=merge old-app new-app"
"$here/mvc" -v --history=merge "$T/old-app" "$T/new-app" | sed "s#$T/##g"
echo

fail=0
check() { if eval "$2"; then echo "  PASS  $1"; else echo "  FAIL  $1"; fail=1; fi; }
echo "AFTER (projects dir now: $(ls "$T/cc/projects" | sed "s#$(enc "$T/")##"))"
check "folder moved"                       '[ -d "$T/new-app" ] && [ ! -d "$T/old-app" ]'
check "source project dir is gone"         '[ ! -d "$SRC_P" ]'
check "all 3 sessions in destination"      '[ "$(ls "$DST_P"/*.jsonl | wc -l | tr -d " ")" = 3 ]'
check "source sessions present"            '[ -f "$DST_P/aaaa-1111.jsonl" ] && [ -f "$DST_P/bbbb-2222.jsonl" ]'
check "destination session untouched"      'grep -q "dst session" "$DST_P/cccc-3333.jsonl"'
check "source memory carried over"         '[ -f "$DST_P/memory/MEMORY.md" ]'
check "cwd rewritten to new path"          'grep -q "\"cwd\":\"$T/new-app\"" "$DST_P/aaaa-1111.jsonl"'
check "no old path left in sessions"       '! grep -q "$T/old-app" "$DST_P"/*.jsonl'
check ".claude.json merged (both keys)"    'python3 -c "import json,sys;p=json.load(open(\"$T/cc/.claude.json\"))[\"projects\"];sys.exit(not(p[\"$T/new-app\"][\"from\"]==\"src\" and p[\"$T/new-app\"][\"shared\"]==\"dst\" and \"$T/old-app\" not in p))"'

echo
echo "SESSIONS IN $(basename "$DST_P" | sed "s#$(enc "$T/")##"):"
for f in "$DST_P"/*.jsonl; do printf '  %s  %s\n' "$(basename "$f")" "$(cat "$f" | sed "s#$T/##g")"; done

if [ "${1:-}" = "--keep" ]; then echo; echo "sandbox kept: $T"; else rm -rf "$T"; fi
[ $fail = 0 ] && echo && echo "ALL PASSED" || { echo; echo "SOME CHECKS FAILED"; exit 1; }
