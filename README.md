# winget-install-gitkraken.cli

Встановлення [GitKraken CLI](https://www.gitkraken.com/cli) (`gk`) на Windows через winget.

## Швидкий варіант

```powershell
winget install gitkraken.cli
```

## Скрипт

`install.ps1` робить те саме, але ідемпотентно: перевіряє наявність winget, не перевстановлює вже
встановлений пакет, приймає ліцензійні угоди без запитів і перевіряє, що `gk` доступний у PATH.

```powershell
# встановити
powershell -ExecutionPolicy Bypass -File .\install.ps1

# оновити вже встановлений пакет
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Upgrade
```

## Після встановлення

```powershell
gk version
gk auth login
```

## Видалення

```powershell
winget uninstall --id GitKraken.cli --exact
```
