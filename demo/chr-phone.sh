#!/bin/sh
# MikroTik CHR (RouterOS 7, ARM64) у QEMU - для Alpine в UserLAnd на Android.
# Запуск: sh chr-phone.sh        Вийти з роутера: Ctrl+A, потім X
# Вхід: admin, пароль порожній (RouterOS попросить задати новий).
set -e
VER=${VER:-7.25.1}
DIR=${DIR:-$HOME/chr}
IMG=$DIR/chr-$VER-arm64.img
mkdir -p "$DIR"; cd "$DIR"

# 1) QEMU + UEFI-прошивка
if ! command -v qemu-system-aarch64 >/dev/null; then
    sudo apk add --no-cache qemu-system-aarch64 qemu-img unzip curl
fi
FW=""
for f in /usr/share/qemu/edk2-aarch64-code.fd /usr/share/AAVMF/QEMU_EFI.fd /usr/share/qemu-efi-aarch64/QEMU_EFI.fd; do
    [ -f "$f" ] && FW=$f && break
done
if [ -z "$FW" ]; then
    sudo apk add --no-cache aavmf 2>/dev/null || true
    FW=$(find /usr/share -name 'QEMU_EFI.fd' -o -name 'edk2-aarch64-code.fd' 2>/dev/null | head -1)
fi
[ -n "$FW" ] || { echo "Не знайдено UEFI-прошивку для aarch64"; exit 1; }

# 2) образ CHR (один раз), диск 512 МБ - місце для контейнера
if [ ! -f "$IMG" ]; then
    curl -fL -o chr.zip "https://download.mikrotik.com/routeros/$VER/chr-$VER-arm64.img.zip"
    unzip -o chr.zip && rm chr.zip
    qemu-img resize -f raw "$IMG" 512M
fi

# 3) запуск. Порти телефона -> CHR: 8080->80 (WebFig), 2222->22 (SSH)
echo "Старт CHR... (на телефоні без KVM - кілька хвилин)"
exec qemu-system-aarch64 -M virt -cpu cortex-a57 -m 512 -smp 2 -nographic \
    -bios "$FW" \
    -drive file="$IMG",format=raw,if=none,id=d0 -device virtio-blk-pci,drive=d0 \
    -netdev user,id=n0,hostfwd=tcp:127.0.0.1:8080-:80,hostfwd=tcp:127.0.0.1:2222-:22 \
    -device virtio-net-pci,netdev=n0
