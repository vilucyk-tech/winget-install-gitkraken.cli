# winget-install-gitkraken.cli

Installers for [GitKraken CLI](https://github.com/gitkraken/gk-cli) (`gk`).

## Windows (winget)

```powershell
winget install --id GitKraken.cli -e
# or
powershell -ExecutionPolicy Bypass -File .\install-gk.ps1 [-Version X.Y.Z]
```

## Linux (`lsb_release`-based)

```bash
./install-gk.sh            # latest release
./install-gk.sh --dry-run  # show what would be installed
./install-gk.sh --version vX.Y.Z --prefix /usr/local/bin
```

The script:

1. Detects the distribution with `lsb_release -is` / `lsb_release -cs`
   (falls back to `/etc/os-release`) and the CPU arch (`amd64` / `arm64`).
2. Picks the install method:
   - Debian/Ubuntu family → `.deb` via `apt-get`
   - Fedora/RHEL/SUSE family → `.rpm` via `dnf` / `yum` / `zypper` / `rpm`
   - otherwise (or no package asset) → archive, binary copied to `--prefix`
3. Resolves the asset from the GitHub release `gitkraken/gk-cli`
   (asset names are matched by pattern, not hardcoded).
4. Verifies SHA-256 if the release ships a checksums file.

Environment: `GK_VERSION`, `GK_PREFIX`, `GITHUB_TOKEN` (rate limit),
`GK_RELEASE_JSON` (saved release JSON for offline testing).

## Tests / CI

```bash
shellcheck install-gk.sh tests/*.sh
tests/dry-run.sh deb        # expected method for the current host: deb | rpm | archive
```

`tests/dry-run.sh` runs the installer in `--dry-run` mode against
`tests/fixtures/release.json` (no network) and checks the selected asset,
including the fallback to an archive. GitHub Actions (`.github/workflows/ci.yml`)
runs ShellCheck and the dry-run in Ubuntu 24.04, Debian 12, Fedora 41 and Arch
containers.
