#!/usr/bin/env bash
# CI smoke test. Runs without real hardware: covers what we can statically.

set -euo pipefail

cd "$(dirname "$0")/.."

bold() { printf '\033[1m== %s ==\033[0m\n' "$*"; }

bold "fannode --version"
bash bin/fannode --version

bold "fannode --help"
bash bin/fannode --help | head -5

bold "fannode (no args) returns non-zero"
if bash bin/fannode 2>/dev/null; then
    echo "FAIL: expected non-zero exit on no args"
    exit 1
fi
echo "OK"

bold "fannode status (with no daemon) returns non-zero"
if bash bin/fannode status 2>/dev/null; then
    echo "FAIL: expected non-zero exit when status file missing"
    exit 1
fi
echo "OK"

bold "applet metadata.json parses"
python3 -m json.tool applet/fannode@customernode/metadata.json > /dev/null

bold "applet settings-schema.json parses"
python3 -m json.tool applet/fannode@customernode/settings-schema.json > /dev/null

bold "icons present"
for state in normal warm hot critical inactive; do
    test -f "applet/fannode@customernode/icons/fannode-${state}.svg" || {
        echo "FAIL: missing icon fannode-${state}.svg"
        exit 1
    }
done
echo "OK"

bold "All smoke checks passed"
