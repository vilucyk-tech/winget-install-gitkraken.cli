# RouterOS v7: повне розгортання контейнера alpine зі змінними середовища.
# Запускати в терміналі RouterOS (WinBox > New Terminal, SSH), НЕ в Claude Code:
#   /import file-name=alpine-env.rsc
#
# Передумови (скрипт їх не робить):
#   1) встановлено пакет container (/system/package/print);
#   2) /system/device-mode/update container=yes + підтвердження кнопкою/перезавантаженням;
#   3) місце для образів: DISK="" - системне сховище (типово для CHR),
#      або назва диска з /disk/print (disk1, usb1, ...).

{
    # ---- параметри ----
    :local DISK ""
    :local NAME "alpine"
    :local ENVL "alpine_env"
    :local VETH "veth-alpine"
    :local BR "containers"
    :local P "containers"
    :if ($DISK != "") do={ :set P ($DISK . "/containers") }

    # ---- мережа: veth + bridge + NAT ----
    :if ([:len [/interface/veth/find where name=$VETH]] = 0) do={
        /interface/veth/add name=$VETH address=172.17.0.2/24 gateway=172.17.0.1
    }
    :if ([:len [/interface/bridge/find where name=$BR]] = 0) do={
        /interface/bridge/add name=$BR
    }
    :if ([:len [/ip/address/find where address="172.17.0.1/24"]] = 0) do={
        /ip/address/add address=172.17.0.1/24 interface=$BR
    }
    :if ([:len [/interface/bridge/port/find where interface=$VETH]] = 0) do={
        /interface/bridge/port/add bridge=$BR interface=$VETH
    }
    :if ([:len [/ip/firewall/nat/find where src-address="172.17.0.0/24" action=masquerade]] = 0) do={
        /ip/firewall/nat/add chain=srcnat action=masquerade src-address=172.17.0.0/24 comment="containers"
    }

    # ---- реєстр і тимчасова тека ----
    /container/config/set registry-url=https://registry-1.docker.io tmpdir=("$P/tmp")

    # ---- змінні середовища ----
    :foreach i in=[/container/envs/find where list=$ENVL] do={ /container/envs/remove $i }
    # POSIX-рядок замість "Europe/Kyiv": працює в Alpine без пакета tzdata
    # (EET UTC+2, літній EEST UTC+3, остання неділя березня 03:00 / жовтня 04:00)
    /container/envs/add list=$ENVL key=TZ value="EET-2EEST,M3.5.0/3,M10.5.0/4"
    /container/envs/add list=$ENVL key=MY_VAR value=test

    # ---- контейнер ----
    :local c [/container/find where name=$NAME]
    :if ([:len $c] > 1) do={ :error "знайдено кілька контейнерів $NAME" }

    :if ([:len $c] = 0) do={
        # без cmd Alpine (/bin/sh без TTY) одразу завершується - тримаємо процес живим
        /container/add name=$NAME remote-image=alpine:latest interface=$VETH \
            root-dir=("$P/$NAME") envlist=$ENVL \
            cmd="tail -f /dev/null" start-on-boot=yes logging=yes
        :set c [/container/find where name=$NAME]
    } else={
        /container/set $c envlist=$ENVL
        :do { /container/stop $c } on-error={}
    }

    # чекаємо, поки образ завантажиться/розпакується або контейнер зупиниться (до 5 хв)
    :local n 0
    :while (([/container/get $c status] != "stopped") && ($n < 300)) do={
        :delay 1s
        :set n ($n + 1)
    }
    :if ([/container/get $c status] != "stopped") do={
        :error ("контейнер не готовий, status=" . [/container/get $c status])
    }

    /container/start $c
    :put ("container $NAME started")
}

/container/envs/print where list="alpine_env"
/container/print where name="alpine"
