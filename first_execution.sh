#!/bin/bash

sudo mkdir /home/gor/SystemIdle
sudo chmod 777 /home/gor/SystemIdle

sudo mkdir /home/gor/SystemIdle/texts
sudo chmod 777 /home/gor/SystemIdle/texts

sudo mkdir /usr/lib/cgi-bin/SystemIdle
sudo chmod 777 /usr/lib/cgi-bin/SystemIdle

sudo mv ./System-Idle/run.sh /usr/lib/cgi-bin/SystemIdle
sudo mv ./System-Idle/check.sh /usr/lib/cgi-bin/SystemIdle
sudo mv ./System-Idle/data.escript /home/gor/SystemIdle/

sudo touch /home/gor/SystemIdleExecution.txt
sudo chmod 777 /home/gor/SystemIdleExecution.txt

sudo rm -r  ./System-Idle
