#!/usr/bin/env bash
# Install GitKraken CLI (gk) on Debian/Ubuntu (tested target: Ubuntu 24.04 "noble").
#
# Order of methods:
#   1. Official .deb from GitHub Releases (gitkraken/gk-cli), installed via apt
#   2. Fallback: npm package @gitkraken/gk (published by GitKraken)
#
# Usage: ./install.sh [--npm]   (--npm forces the npm method)

set -euo pipefail

REPO="gitkraken/gk-cli"
FORCE_NPM=0
[[ "${1:-}" == "--npm" ]] && FORCE_NPM=1

log() { printf '\033[1;34m[gk-install]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[gk-install]\033[0m %s\n' "$*" >&2; exit 1; }

if command -v gk >/dev/null 2>&1; then
  log "gk already installed: $(gk version 2>/dev/null | head -n1)"
  exit 0
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  log "Detected: ${PRETTY_NAME:-unknown} (codename: ${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo '?')})"
fi

SUDO=""
if [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || die "Run as root or install sudo."
  SUDO="sudo"
fi

install_deb() {
  command -v apt-get >/dev/null 2>&1 || { log "apt-get not found, skipping .deb method."; return 1; }
  command -v curl >/dev/null 2>&1 || { log "curl not found, skipping .deb method."; return 1; }

  local arch url tmp
  arch="$(dpkg --print-architecture)"   # amd64 | arm64
  log "Looking up latest release of ${REPO} for ${arch}..."

  url="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep -oE '"browser_download_url":[[:space:]]*"[^"]+\.deb"' \
        | sed -E 's/.*"(https[^"]+)"/\1/' \
        | grep -iE "linux.*${arch}|${arch}.*linux" \
        | head -n1)" || true

  [[ -n "${url}" ]] || { log "No matching .deb asset found."; return 1; }

  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN
  log "Downloading ${url}"
  curl -fL --retry 3 -o "${tmp}/gk.deb" "${url}" || return 1

  log "Installing via apt (resolves dependencies)..."
  ${SUDO} apt-get install -y "${tmp}/gk.deb"
}

install_npm() {
  command -v npm >/dev/null 2>&1 || die "npm not found. Install Node.js (e.g. 'sudo apt install nodejs npm') and retry."
  log "Installing @gitkraken/gk via npm..."
  if [[ -w "$(npm prefix -g)/lib" ]]; then
    npm install -g @gitkraken/gk
  else
    ${SUDO} npm install -g @gitkraken/gk
  fi
}

if [[ ${FORCE_NPM} -eq 1 ]]; then
  install_npm
else
  install_deb || { log "Falling back to npm."; install_npm; }
fi

command -v gk >/dev/null 2>&1 || die "Installation finished but 'gk' is not on PATH."
log "Installed: $(gk version 2>/dev/null | head -n1)"
log "Next step: gk auth login"
