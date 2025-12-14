#!/bin/bash

############################################
# Usage:
#   ./decode_passwords.sh /path/to/config
#
# Generates:
#   /path/to/config.clear
############################################

CONFIG_FILE="$1"

if [ -z "$CONFIG_FILE" ]; then
    echo "ERROR: Missing config file argument."
    echo "Usage: $0 /path/to/wlan_config"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: File not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

DECODE() {
    php -r '
        $encoded = $argv[1];
        $k = getenv("KEY_J3D5ETO");
        $f="strtr";
        $r = base64_decode($f($encoded,"-_","+/"), true);
        $key = unpack("C*", $k);
        $l = count($key);
        $p="";
        for($i=0,$n=strlen($r);$i<$n;$i++){
            $p .= chr(ord($r[$i]) ^ $key[$i % $l + 1]);
        }
        echo $p;
    ' "$1"
}

OUT="${CONFIG_FILE}.clear"
echo '# AUTO-GENERATED DO NOT EDIT' > "$OUT"

# Only capture valid lines like:
# PASS_SOMETHING='encodedvalue'
grep -E "^[[:space:]]*PASS_[A-Za-z0-9_]+='[^']*'" "$CONFIG_FILE" | \
while IFS='=' read -r VAR VALUE; do

    VAR=$(echo "$VAR" | tr -d ' ')
    ENC=$(echo "$VALUE" | sed -E "s/^'([^']*)'.*/\1/")

    if [ -n "$ENC" ]; then
        CLEAR=$(DECODE "$ENC")
        echo "${VAR}_CLEAR='$CLEAR'" >> "$OUT"
    fi
done

echo "Generated: $OUT"
