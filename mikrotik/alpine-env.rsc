# RouterOS v7: environment variables for the Alpine container
# Import: /import file-name=alpine-env.rsc

/container/envs
# remove old entries of this list so the import can be run again
remove [find where list="alpine_env"]
add list=alpine_env key=TZ value="Europe/Kyiv"
add list=alpine_env key=MY_VAR value=test
print where list="alpine_env"
