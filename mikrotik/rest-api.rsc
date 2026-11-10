# RouterOS v7 (CHR): REST API через HTTPS з сертифікатом Let's Encrypt.
# Запуск у терміналі RouterOS: /import file-name=rest-api.rsc
# Передумова: порти 80 і 443 CHR доступні з інтернету
# (на вищому роутері/фаєрволі ESXi-мережі - проброс портів на CHR).

{
    # ---- DDNS: публічне ім'я xxxx.sn.mynetname.net ----
    /ip/cloud/set ddns-enabled=yes ddns-update-interval=1m
    :local n 0
    :while (([/ip/cloud/get dns-name] = "") && ($n < 30)) do={ :delay 1s; :set n ($n + 1) }
    :local dns [/ip/cloud/get dns-name]
    :if ($dns = "") do={ :error "DDNS не видав ім'я - перевірте вихід в інтернет" }
    :put ("DNS name: " . $dns)

    # ---- фаєрвол: дозволити 80/443 на вхід (на початок ланцюжка) ----
    :if ([:len [/ip/firewall/filter/find where comment="rest-api"]] = 0) do={
        :if ([:len [/ip/firewall/filter/find]] > 0) do={
            /ip/firewall/filter/add chain=input protocol=tcp dst-port=80,443 action=accept comment="rest-api" place-before=0
        } else={
            /ip/firewall/filter/add chain=input protocol=tcp dst-port=80,443 action=accept comment="rest-api"
        }
    }

    # ---- сертифікат Let's Encrypt (HTTP-01 потребує порт 80) ----
    /ip/service/set www disabled=no port=80
    /certificate/enable-ssl-certificate dns-name=$dns
    # сертифікат автоматично призначається сервісу www-ssl
    /ip/service/set www-ssl disabled=no port=443

    # ---- користувач з мінімальними правами ----
    :if ([:len [/user/group/find where name="rest"]] = 0) do={
        /user/group/add name=rest policy=read,write,api,rest-api,test
    }
    :if ([:len [/user/find where name="claude"]] = 0) do={
        /user/add name=claude group=rest disabled=yes
    }
    :put "Далі вручну: /user/set claude password=\"<довгий пароль>\" disabled=no"
}

/ip/service/print where name~"www"
/certificate/print where common-name~"mynetname"

# ---- ВІДКАТ (коли доступ більше не потрібен) ----
# /user/disable claude
# /ip/service/set www,www-ssl disabled=yes
# /ip/firewall/filter/remove [find comment="rest-api"]
# /ip/cloud/set ddns-enabled=no
