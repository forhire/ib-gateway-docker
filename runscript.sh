#!/bin/bash

socat -d -d -d  TCP-LISTEN:${SOCAT_LISTEN_PORT},fork,forever,reuseaddr,keepalive,keepidle=10,keepintvl=10,keepcnt=2 TCP:${SOCAT_DEST_ADDR}:${SOCAT_DEST_PORT} &

xvfb-daemon-run /opt/IBController/scripts/displaybannerandlaunch.sh 

ps -ef | cat
cat /Logs/ibc*.txt /opt/IBController/Logs/ibc*.txt

