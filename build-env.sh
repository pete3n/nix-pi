#!/bin/sh

read -p "Enter SSID for the configuration network: " ssid
read -s -p "Enter password for the configuration network: " password
echo 

echo "CONFIG_NET_SSID=\"$ssid\"" > .env
echo "CONFIG_NET_PASSWORD=\"$password\"" >> .env

echo "SSID and password have been saved to .env."
