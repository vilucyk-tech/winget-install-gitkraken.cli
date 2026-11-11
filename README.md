# winget-install-gitkraken.cli

Installs [GitKraken CLI](https://github.com/gitkraken/gk-cli) (`gk`) on Windows via winget.

## Quick install

```powershell
winget install --id GitKraken.cli --exact
```

## Using the script

```powershell
# One-time: allow local scripts for the current user
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
# If the file was downloaded from the internet:
Unblock-File .\install.ps1

.\install.ps1
```

The script checks whether `gk` and `winget` are present, installs the package, and refreshes `PATH` for the current session.

If the package ID has changed, check it with: `winget search gitkraken`.

## After installation

```powershell
gk version
gk auth login
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `winget` is not recognized | Install/update "App Installer" from Microsoft Store |
| `gk` not found after install | Open a new terminal |
| Script blocked by execution policy | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, then `Unblock-File .\install.ps1` |

## See also

- [`chr/`](chr/README.md) — MikroTik RouterOS CHR virtual router in Hyper-V (`chr\New-ChrVm.ps1`).
