#!/usr/bin/env bash
# Install GitKraken CLI (gk) on Linux.
#
# Linux counterpart of `winget install GitKraken.cli`: the distribution is
# detected with `lsb_release` (falling back to /etc/os-release) and the
# matching release asset (.deb / .rpm / archive) is installed.
#
# Usage: ./install-gk.sh [--dry-run] [--version vX.Y.Z] [--prefix DIR]
#
# Environment:
#   GK_VERSION        release tag to install (default: latest)
#   GK_PREFIX         install dir for archive installs (default: /usr/local/bin)
#   GK_RELEASE_JSON   path to a saved GitHub release JSON (offline/testing)
#   GITHUB_TOKEN      optional, raises GitHub API rate limit
#   GK_OS_RELEASE     os-release file to read (default: /etc/os-release; testing)

set -euo pipefail

REPO="gitkraken/gk-cli"
GK_TAG="${GK_VERSION:-latest}"
PREFIX="${GK_PREFIX:-/usr/local/bin}"
DRY_RUN=0
OS_RELEASE="${GK_OS_RELEASE:-/etc/os-release}"

log()  { printf '[gk-install] %s\n' "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }
run()  { if (( DRY_RUN )); then log "dry-run: $*"; else "$@"; fi; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --version) GK_TAG="${2:?--version needs a value}"; shift ;;
    --prefix)  PREFIX="${2:?--prefix needs a value}"; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

[[ "$(uname -s)" == Linux ]] || die "this script is for Linux; on Windows use install-gk.ps1 (winget)"

SUDO=""
if (( EUID != 0 )); then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else die "run as root or install sudo"; fi
fi

# --- distribution detection ------------------------------------------------
detect_distro() {
  local id="" codename="" like="" os_id="" os_codename=""
  if command -v lsb_release >/dev/null 2>&1; then
    id="$(lsb_release -is 2>/dev/null || true)"
    codename="$(lsb_release -cs 2>/dev/null || true)"
  fi
  if [[ -r "${OS_RELEASE}" ]]; then
    # Read in a subshell: os-release defines VERSION etc., which must not
    # leak into this script's namespace.
    local osr
    # shellcheck disable=SC1090,SC1091
    osr="$(. "${OS_RELEASE}"; printf '%s\n%s\n%s\n' "${ID:-}" "${VERSION_CODENAME:-}" "${ID_LIKE:-}")"
    # $(...) strips trailing empty lines (e.g. no ID_LIKE on Debian/Fedora),
    # so a short read is expected and must not trip `set -e`.
    { read -r os_id || true; read -r os_codename || true; read -r like || true; } <<<"$osr"
    [[ -z "$id" ]] && id="$os_id"
    [[ -z "$codename" ]] && codename="$os_codename"
  fi
  DISTRO_ID="$(tr '[:upper:]' '[:lower:]' <<<"$id")"
  DISTRO_CODENAME="${codename:-unknown}"
  DISTRO_LIKE="$(tr '[:upper:]' '[:lower:]' <<<"$like")"
  OS_ID="$(tr '[:upper:]' '[:lower:]' <<<"$os_id")"
}

pkg_family() {
  # lsb_release IDs differ from os-release ones (e.g. RedHatEnterprise vs rhel),
  # so match on both plus ID_LIKE.
  local s=" $DISTRO_ID $OS_ID $DISTRO_LIKE "
  case "$s" in
    *" debian "*|*" ubuntu "*|*" linuxmint "*|*" pop "*|*" raspbian "*|*" kali "*) echo deb ;;
    *" fedora "*|*" rhel "*|*" redhatenterprise"*|*" centos "*|*" rocky "*|*" almalinux "*|*" suse "*|*" opensuse"*|*" sles "*|*" amzn "*) echo rpm ;;
    *) echo archive ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac
}

# --- release lookup --------------------------------------------------------
fetch_release_json() {
  if [[ -n "${GK_RELEASE_JSON:-}" ]]; then cat "$GK_RELEASE_JSON"; return; fi
  local url="https://api.github.com/repos/$REPO/releases/latest"
  [[ "$GK_TAG" != latest ]] && url="https://api.github.com/repos/$REPO/releases/tags/$GK_TAG"
  local auth=()
  [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  curl -fsSL "${auth[@]}" -H 'Accept: application/vnd.github+json' "$url"
}

# Prints download URLs of assets, one per line.
asset_urls() { grep -o '"browser_download_url": *"[^"]*"' | sed 's/.*"\(https[^"]*\)"$/\1/'; }

# pick_asset <urls> <arch> <regex-for-extension>
pick_asset() {
  local arch="$1" ext="$2" alt
  case "$arch" in amd64) alt='(amd64|x86_64|x64)' ;; arm64) alt='(arm64|aarch64)' ;; esac
  grep -Ei "linux" | grep -Ei "[_.-]${alt}[_.-]" | grep -Ei "${ext}\$" | head -n1 || true
}

verify_checksum() {
  local file="$1" name="$2" sums_url="$3"
  if [[ -z "$sums_url" ]]; then log "no checksums asset in release; skipping verification"; return; fi
  local sums; sums="$(curl -fsSL "$sums_url")"
  local expected; expected="$(awk -v n="$name" '$2==n || $2=="*"n {print $1}' <<<"$sums" | head -n1)"
  [[ -n "$expected" ]] || die "checksum for $name not found in $(basename "$sums_url")"
  local actual; actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$expected" == "$actual" ]] || die "SHA-256 mismatch for $name (expected $expected, got $actual)"
  log "SHA-256 OK"
}

main() {
  need curl
  detect_distro
  local arch family
  arch="$(detect_arch)"
  family="$(pkg_family)"
  log "distro: ${DISTRO_ID:-unknown} ($DISTRO_CODENAME), arch: $arch, method: $family"

  local json urls
  json="$(fetch_release_json)" || die "cannot fetch release info for $REPO ($GK_TAG)"
  urls="$(asset_urls <<<"$json")"
  [[ -n "$urls" ]] || die "release has no downloadable assets"

  local url=""
  case "$family" in
    deb) url="$(pick_asset "$arch" '\.deb' <<<"$urls")" ;;
    rpm) url="$(pick_asset "$arch" '\.rpm' <<<"$urls")" ;;
  esac
  if [[ -z "$url" ]]; then
    family=archive
    url="$(pick_asset "$arch" '\.(tar\.gz|tgz|zip)' <<<"$urls")"
  fi
  [[ -n "$url" ]] || die "no Linux/$arch asset found in release"
  local sums_url; sums_url="$(grep -Ei '(checksums|sha256)[^/]*$' <<<"$urls" | head -n1 || true)"

  local name; name="$(basename "$url")"
  log "asset: $name"

  if (( DRY_RUN )); then
    log "dry-run: would download $url"
    [[ -n "$sums_url" ]] && log "dry-run: would verify against $(basename "$sums_url")"
  fi

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  run curl -fsSL -o "$tmp/$name" "$url"
  (( DRY_RUN )) || verify_checksum "$tmp/$name" "$name" "$sums_url"

  case "$family" in
    deb)
      run $SUDO apt-get install -y "$tmp/$name" ;;
    rpm)
      if   command -v dnf    >/dev/null; then run $SUDO dnf install -y "$tmp/$name"
      elif command -v yum    >/dev/null; then run $SUDO yum install -y "$tmp/$name"
      elif command -v zypper >/dev/null; then run $SUDO zypper --non-interactive install --allow-unsigned-rpm "$tmp/$name"
      else run $SUDO rpm -Uvh "$tmp/$name"; fi ;;
    archive)
      run mkdir -p "$tmp/x"
      case "$name" in
        *.zip) need unzip; run unzip -q "$tmp/$name" -d "$tmp/x" ;;
        *)     run tar -xzf "$tmp/$name" -C "$tmp/x" ;;
      esac
      if (( DRY_RUN )); then
        log "dry-run: would install gk binary to $PREFIX/gk"
      else
        local bin; bin="$(find "$tmp/x" -type f -name gk | head -n1)"
        [[ -n "$bin" ]] || die "gk binary not found in archive"
        $SUDO install -Dm755 "$bin" "$PREFIX/gk"
      fi ;;
  esac

  if (( DRY_RUN )); then log "dry-run complete"; return; fi
  command -v gk >/dev/null 2>&1 || die "installation finished but gk is not on PATH"
  log "installed: $(gk version 2>/dev/null || echo gk)"
}

main
