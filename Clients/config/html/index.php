Hello neighbour<br>
<?php
/*
   Client-isolation challenge: reaching another client's web server should only
   be possible from specific subnets. The source subnet decides which flag you
   get. Flags are intentionally in cleartext here - this page IS the challenge.
   Gates are anchored at position 0 (strpos === 0) so the subnet must be a real
   prefix of the client address, not merely appear somewhere in it.
*/
if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') === 0) {        // only OPN
    echo "flag{3b23cd3e5d462c6cacc20f52f5c92244e1188bde}";
} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') === 0) {   // only HIDDEN
    echo "flag{763fde6ad2602841c2a465607cc2ef27f5f847c2}";
} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') === 0) {   // only PSK
    echo "flag{edfdf342848f5559bce9750c98b7018da3d9270e}";
} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.3.') === 0) {   // only WPS
    echo "flag{90e72231ab8119c3a5511bbddd1cbeaf587d4d12}";
} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') === 0) {   // only MGT
    echo "flag{b9e648f3a1c4f49b7973519a3dc1eee3a45f28bb}";
} else {
    echo "Sorry, No FLAG here";
}
?>
