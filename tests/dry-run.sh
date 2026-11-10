#!/usr/bin/env bash
# Dry-run install-gk.sh against a fixture release and check the chosen asset.
# Usage: tests/dry-run.sh <expected-method: deb|rpm|archive>
set -euo pipefail
cd "$(dirname "$0")/.."
expected="${1:?expected method (deb|rpm|archive)}"
fixture="tests/fixtures/release.json"
# Optional: GK_OS_RELEASE / PATH overrides are honoured for local simulation.
fail() { echo "FAIL: $*" >&2; exit 1; }

case "$(uname -m)" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; *) fail "unsupported arch" ;; esac
case "${expected}" in deb) ext=deb ;; rpm) ext=rpm ;; archive) ext=zip ;; *) fail "bad method" ;; esac

out="$(GK_RELEASE_JSON="${fixture}" ./install-gk.sh --dry-run 2>&1)" || { echo "${out}"; fail "script exited non-zero"; }
echo "${out}"
grep -q "method: ${expected}" <<<"${out}" || fail "method is not ${expected}"
grep -q "asset: gk_0.0.0_linux_${arch}.${ext}" <<<"${out}" || fail "wrong asset for ${arch}/${ext}"
grep -q "dry-run complete" <<<"${out}" || fail "dry-run did not complete"

# Fallback: no package for this family -> archive
if [[ "${expected}" != archive ]]; then
  tmp="$(mktemp)"; trap 'rm -f "${tmp}"' EXIT
  grep -v "\.${ext}\"" "${fixture}" > "${tmp}"
  out="$(GK_RELEASE_JSON="${tmp}" ./install-gk.sh --dry-run 2>&1)"
  grep -q "asset: gk_0.0.0_linux_amd64.zip" <<<"${out}" || [[ "${arch}" != amd64 ]] || fail "archive fallback not used"
fi
echo "PASS (${expected}, ${arch})"
