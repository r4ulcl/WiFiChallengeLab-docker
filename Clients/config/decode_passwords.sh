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
    echo "Usage: $0 /path/to/wlan_config_aps"
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

# Find PASS_ variables
for VAR in $(grep -oE '^PASS_[A-Za-z0-9_]+' "$CONFIG_FILE"); do
    ENC=$(grep "^$VAR=" "$CONFIG_FILE" | sed -E "s/^[^']*'([^']*)'.*/\1/")
    CLEAR=$(DECODE "$ENC")

    # Use single quotes instead of double
    echo "${VAR}_CLEAR='$CLEAR'" >> "$OUT"
done

echo "Generated: $OUT"
