# winget-install-gitkraken.cli

Scripts that install [GitKraken CLI](https://github.com/gitkraken/gk-cli) (`gk`).

## Windows (winget)

```powershell
.\install.ps1
# or manually:
winget install --id GitKraken.cli --exact
```

If the package ID has changed, check it with: `winget search gitkraken`.

## Ubuntu / Debian (tested target: Ubuntu 24.04 "noble")

```bash
chmod +x install.sh
./install.sh          # official .deb from GitHub Releases, falls back to npm
./install.sh --npm    # npm only (@gitkraken/gk)
```

The `.deb` package is installed with `apt-get install ./file.deb`, so apt resolves its dependencies.
No separate APT repository is added, so `$(lsb_release -cs)` is printed for information only.

## After installation

```bash
gk version
gk auth login
```
