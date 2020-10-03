#!/usr/bin/env bash
# Licensed under the ISC License.
# Copyright 2020, Johan Thorén <johan@thoren.xyz>

relay_list="$(mullvad relay list)"

country="$(echo "$relay_list" | grep -Evsh '^(#|\s|\t|$)' | \
           uniq | sort | dmenu -l 10)"

if [ -z "$country" ]; then
    notify-send -a "Mullvad" "Aborted: No country selected."
    exit 1
fi

country_name="${country%%[[:space:]]\(*}"
export country_name

country_code_with_paren="${country##*\(}"
country_code="${country_code_with_paren%*\)}"

city="$(echo "$relay_list" | \
        perl -ne '/^(.*)/; $i = length $1; $j && $i >= $j and print, next; $j = 0; /$ENV{country_name}/ and $j = $i + 1, print' | \
        grep '^\s[A-Z]' | sed 's/^\s*//' | awk -F '@' '{ print $1 }' | uniq | sort | dmenu -l 10)"

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
