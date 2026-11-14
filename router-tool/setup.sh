#!/usr/bin/env bash
# Шаблон налаштування середовища: перевірка pip -> venv -> залежності.
set -euo pipefail
cd "$(dirname "$0")"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null || { echo "Немає $PY. Встановіть Python 3."; exit 1; }
"$PY" -c 'import sys; sys.exit(sys.version_info < (3, 9))' \
  || { echo "Потрібен Python 3.9+"; exit 1; }

# 1. Переконатися, що pip запускається як модуль (рекомендація packaging.python.org)
if ! "$PY" -m pip --version >/dev/null 2>&1; then
  echo "pip не знайдено, пробую ensurepip..."
  "$PY" -m ensurepip --default-pip 2>/dev/null || {
    echo "ensurepip недоступний (Debian/Ubuntu вимикають його)."
    echo "Виконайте: sudo apt install python3-pip python3-venv"
    exit 1
  }
fi

# 2. Ізольоване середовище, щоб не чіпати системний Python
if [ ! -d .venv ]; then
  "$PY" -m venv .venv || { echo "Виконайте: sudo apt install python3-venv"; exit 1; }
fi

# 3. Залежності
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements.txt
echo "Готово. Запуск: ROUTER_PASS=... .venv/bin/python router_status.py"
