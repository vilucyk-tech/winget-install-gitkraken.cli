#!/bin/sh
# Демо: Alpine-контейнер зі змінними TZ і MY_VAR (як /container/envs у RouterOS).
# Потрібно: Linux, curl, tar, python3. Повний режим (справжній Alpine) - root + chroot.
# Без root - спрощений режим: ті самі змінні в поточній оболонці.
set -e

TZ_NAME="Europe/Kyiv"
TZ_POSIX="EET-2EEST,M3.5.0/3,M10.5.0/4"
MY_VAR="test"

show() {  # $1 - заголовок, далі - команда запуску
    t=$1; shift
    echo "== $t =="
    "$@" /bin/sh -c 'env | grep -E "^(TZ|MY_VAR)="; date'
    echo
}

plain() { env -i PATH=/usr/bin:/bin TZ="$TZ_VAL" MY_VAR="$MY_VAR" "$@"; }

if [ "$(id -u)" != 0 ] || ! command -v chroot >/dev/null; then
    echo "[спрощений режим: немає root/chroot]"; echo
    TZ_VAL=$TZ_POSIX; show "TZ=$TZ_POSIX" plain
    TZ_VAL=$TZ_NAME;  show "TZ=$TZ_NAME (працює, лише якщо на хості є tzdata)" plain
    exit 0
fi

DIR=${DIR:-/tmp/alpine-demo}
ROOT=$DIR/rootfs
if [ ! -f "$ROOT/etc/alpine-release" ]; then
    echo "[завантаження alpine:latest з mirror.gcr.io]"
    mkdir -p "$ROOT"
    R=https://mirror.gcr.io/v2/library/alpine
    case $(uname -m) in aarch64|arm64) ARCH=arm64;; armv7*) ARCH=arm;; *) ARCH=amd64;; esac
    ACC='-H Accept:application/vnd.oci.image.index.v1+json -H Accept:application/vnd.docker.distribution.manifest.list.v2+json -H Accept:application/vnd.oci.image.manifest.v1+json -H Accept:application/vnd.docker.distribution.manifest.v2+json'
    D=$(curl -fsS $ACC $R/manifests/latest | python3 -c 'import sys,json;print([m["digest"] for m in json.load(sys.stdin)["manifests"] if m["platform"]["os"]=="linux" and m["platform"]["architecture"]==sys.argv[1]][0])' $ARCH)
    L=$(curl -fsS $ACC $R/manifests/$D | python3 -c 'import sys,json;print(json.load(sys.stdin)["layers"][0]["digest"])')
    curl -fsSL $R/blobs/$L | tar -xz -C "$ROOT"
fi
echo "[Alpine $(cat "$ROOT/etc/alpine-release")]"; echo

box() { chroot "$ROOT" /usr/bin/env -i PATH=/usr/bin:/bin TZ="$TZ_VAL" MY_VAR="$MY_VAR" "$@"; }
TZ_VAL=$TZ_NAME;  show "TZ=$TZ_NAME (без tzdata -> UTC)" box
TZ_VAL=$TZ_POSIX; show "TZ=$TZ_POSIX (київський час)" box
echo "== контроль =="; date -u
