#!/bin/bash

############################################
# Uses existing environment variables
# Generates:
#   /root/wlan_config.clear
############################################

if [ -z "$KEY_J3D5ETO" ]; then
    echo "ERROR: KEY_J3D5ETO is not set in environment."
    exit 1
fi

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

OUT="/root/wlan_config.clear"
echo '# AUTO-GENERATED DO NOT EDIT' > "$OUT"

# Iterate over existing environment variables
env | grep -E '^PASS_[A-Za-z0-9_]+=' | while IFS='=' read -r VAR ENC; do
    if [ -n "$ENC" ]; then
        CLEAR=$(DECODE "$ENC")
        echo "${VAR}_CLEAR='$CLEAR'" >> "$OUT"
    fi
done

echo "Generated: $OUT"
