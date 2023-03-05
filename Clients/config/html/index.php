<?php
if  (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPN
    echo "flag{jg67f7sad87g387g}";
} elseif  (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only HIDDEN
    echo "flag{IkZ4ZeDqgfQ3eUU}";
} elseif  (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK
    echo "flag{QvD1ervLa4EwVh81Tfm0}";
} elseif  (strpos($_SERVER['REMOTE_ADDR'], '192.168.3.') !== false) { //only WPS
        echo "flag{pRH6IlFp2OF49x2}";
} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
    echo "flag{y67gasdG6hm8hfn7gh}";
} else {
    echo "Sorry, No FLAG here";

}
?>