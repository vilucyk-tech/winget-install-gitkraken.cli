# RouterOS v7: змінні для контейнера alpine
# Файл у корені Files, далі: /import file-name=alpine-env.rsc

:foreach i in=[/container/envs/find where list="alpine_env"] do={
    /container/envs/remove $i
}
/container/envs/add list=alpine_env key=TZ value="Europe/Kyiv"
/container/envs/add list=alpine_env key=MY_VAR value=test
/container/envs/print where list="alpine_env"
