#!/usr/bin/env bash
# Licensed under the ISC License.
# Copyright 2020, Johan Thorén <johan@thoren.xyz>

relay_list="$(mullvad relay list)"

dmenu_cmd() {
    dmenu -l 10
}

if uname -a | grep -Eq '20\.04\.[0-9]+-Ubuntu'; then
    dmenu_cmd() {
        dmenu -i -l 10 -fn 'Ubuntu Regular-13' -sb '#e95420' -nb 'black'
    }
fi

country=$(echo "$relay_list" | grep -Evsh '^(#|\s|\t|$)' | uniq | sort | \
    dmenu_cmd)

if [ -z "$country" ]; then
    notify-send -a "Mullvad" "Aborted: No country selected."
    exit 1
fi

country_name="${country%%[[:space:]]\(*}"
export country_name

country_code_with_paren="${country##*\(}"
country_code="${country_code_with_paren%*\)}"

city=$(echo "$relay_list" | \
    perl -ne '/^(.*)/; $i = length $1; $j && $i >= $j and print, next; $j = 0; /$ENV{country_name}/ and $j = $i + 1, print' | \
    grep '^\s[A-Z]' | sed 's/^\s*//' | awk -F '@' '{ print $1 }' | uniq | \
    sort | dmenu_cmd)

if [ -z "$city" ]; then
    notify-send -a "Mullvad" "Aborted: No city selected."
    exit 1
fi

city_name="${city%%[[:space:]]\(*}"
export city_name

city_code_with_paren="${city##*\(}"
city_code="${city_code_with_paren%%\)*}"

if [ ! ${#country_code} -eq 2 ] && [ ${#city_code} -eq 3 ]; then
    notify-send -a "Mullvad" "Aborted: Incorrect country or city code."
    exit 1
fi

# Test if there are wireguard connections available.
echo "$relay_list" list | \
    perl -ne '/^(\s*)/; $i = length $1; $j && $i >= $j and print, next; $j = 0; /$ENV{city_name}/ and $j = $i + 1, print' | \
    grep -q WireGuard
wireguard=$?

if [ $wireguard -eq 0 ]; then
    protocol="wireguard"
    proto_msg="WireGuard"
else
    protocol="openvpn"
    proto_msg="OpenVPN"
fi

notify-send -a "Mullvad" \
    "Connecting to ${city_name}, ${country_name} using $proto_msg."
mullvad relay set tunnel-protocol $protocol > /dev/null 2>&1
mullvad relay set location $country_code $city_code > /dev/null 2>&1

## Adding connect command + connection check
# now that relay is updated, proceed to connect
mullvad connect

# wait for connection to be made so status command returns "Connected"
sleep 5

# collect current connection info to check for intended connection result
current_ip=$(mullvad status | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
current_country_code_with_num=$(echo "$relay_list" | grep "$current_ip" | \
  cut -d "-" -f 1 | xargs)
current_country_code=${current_country_code_with_num:0:2}
current_city_code=$(echo "$relay_list" | grep -e '(...)' -e "$current_ip" | \
  grep -B1 "$current_ip" | head -1 | awk -F'[()]' '{print $2}')

# do the check and notify accordingly
if [[ $current_country_code = $country_code ]] && \
   [[ $current_city_code = $city_code ]]; then
    notify-send -a "Mullvad" "Connected to ${city_name}, ${country_name} using $proto_msg."
else
    notify-send -a "Mullvad" "Failed connecting to ${city_name}, ${country_name} \
    using $proto_msg."
fi
