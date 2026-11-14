"""Шаблон: список клієнтів роутера TP-Link.
Адреса й пароль беруться зі змінних середовища, не з коду.
  ROUTER_URL  (за замовчуванням http://192.168.0.1)
  ROUTER_PASS (обов'язково)
Підтримку своєї моделі перевірте в документації tplinkrouterc6u.
"""
import os
import sys

from tplinkrouterc6u import TplinkRouterProvider


def main() -> int:
    password = os.environ.get("ROUTER_PASS")
    if not password:
        print("Задайте ROUTER_PASS", file=sys.stderr)
        return 1
    url = os.environ.get("ROUTER_URL", "http://192.168.0.1")

    router = TplinkRouterProvider.get_client(url, password)
    try:
        router.authorize()
        status = router.get_status()
        print(f"Клієнтів: {status.clients_total}")
        for d in status.devices:
            print(d.ipaddr, d.macaddr, d.hostname)
    finally:
        router.logout()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
