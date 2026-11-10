# RouterOS v7: змінні для контейнера alpine
# Файл у корені Files, далі: /import file-name=alpine-env.rsc

:foreach i in=[/container/envs/find where list="alpine_env"] do={
    /container/envs/remove $i
}
/container/envs/add list=alpine_env key=TZ value="Europe/Kyiv"
/container/envs/add list=alpine_env key=MY_VAR value=test
/container/envs/print where list="alpine_env"

# прив'язка списку до контейнера і перезапуск
{
    :local c [/container/find where name="alpine"]
    :if ([:len $c] != 1) do={ :error "container alpine: знайдено $[:len $c] записів, очікувався 1" }
    /container/set $c envlist=alpine_env
    # stop асинхронний; якщо контейнер уже зупинений, помилку ігноруємо
    :do { /container/stop $c } on-error={}
    :local n 0
    :while (([/container/get $c status] != "stopped") && ($n < 30)) do={
        :delay 1s
        :set n ($n + 1)
    }
    /container/start $c
}
