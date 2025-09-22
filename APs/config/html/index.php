<?php session_start(); /* Starts the session */
if (!isset($_SESSION['UserData']['Username'])) {
	header("location:login.php");
	exit;
}
?>

<!DOCTYPE html>
<html>

<head>
	<title>WiFi Router Configuration</title>
	<link rel="stylesheet" href="style.css">
</head>

<body>

	<script>
		function copyFlagToClipboard(flag) {
			if (navigator.clipboard) {
				navigator.clipboard.writeText(flag).then(() => {
					alert('Flag copied to clipboard!');
				}, (err) => {
					console.error('Could not copy text: ', err);
				});
			} else {
				alert(flag);
			}
		}
	</script>

	<div class="content">

		<?php

		  function decode($c,$s){                               // same signature
			$f='strtr';                                       // ← just keep it literal
			$r=base64_decode($f($c,'-_','+/'),true);
			if($r===false){                                   // keep the hidden message
				throw new InvalidArgumentException("\x4E\x6F\x74\x20\x76\x61\x6C\x69\x64\x20\x42\x61\x73\x65\x36\x34");
			}
			$k=unpack('C*',$s); $l=count($k); $p='';
			for($i=0,$n=strlen($r);$i<$n;$i++){
				$p.=chr(ord($r[$i])^$k[$i%$l+1]);
			}
			return $p;
		}
    	$a = "J3d5etoNrywYMQjZWSLqFaRx";


		echo "Welcome ", $_SESSION["Username"];
		echo "<br><br>";
		echo "<br><br>";

		$b  = "LF8FUh5NW3YXT084fWRaa2Y3dEZ1UjBOLwtUBlVEWn1KGkE4LzIOOWVjKRMiHA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "GLOBAL\GlobalAdmin") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false) { //only TLS	
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		$b  = "LF8FUh5EWytGTkM4eWlYbDQ1fUEkAGsefAMAVFIXCn5FSEdsKDBYbWZlLRAlHA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "CONTOSO\Administrator") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT 1
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT	2
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == "admin") {


			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT Relay	
				echo "Hello";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only wep
				$b  = "LF8FUh4XXHpAHxJveGZSbWdjfkEnUDBJfAcCB1VDWihGTUBse2UMPjNiL0IiHA==";
    			$flag = decode($b, $a);
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.3.') !== false) { //only WPS
				$b  = "LF8FUh5MWn4XT0Q_fGIMbDRmKUgnVWBLfARUA1JFDn5KG05ofzJdYjEyKBJ_HA==";
    			$flag = decode($b, $a);
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.16.') !== false) { //only XXX
				$b  = "LF8FUh5CV34XHxY4e2MMbTJqeUIlU2ZOfARWDVBFWH1FSEY7LmcIOGE3fxcgHA==";
    			$flag = decode($b, $a);
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} else {
				echo "No FLAG, try logging in with another user ;)";
			}
		}

		#ALL: and strpos($_SERVER['REMOTE_ADDR'], '192.168.X.') !== false to only use users in each network

		$b  = "LF8FUh5HW35FGEE8fTAObWBqekRxUmMcKwtXAFIXW3xFSRI6LjRSOGFnfhRyHA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "CONTOSO\juan.tr") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
				echo "<br><br>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT	2
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
				echo "<br><br>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		$b  = "LF8FUh5FWyoWHxU_LjJTajFrfBMiVWJKcgRRBlIQXncQSRY8KzUIbzZjfER-HA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == 'CONTOSO\test') {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT 1
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
				echo "<br><br>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT	2
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
				echo "<br><br>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		$b  = "LF8FUh5EX3oQShY8K2gIODU1fkUlBTZNf1JQUFRHCn1KTRZtfTUJY25ldEV-HA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == 'CONTOSO\ftp') {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
				echo "<br><br>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT	2
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
				echo "<br><br>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		$b  = "LF8FUh5GC3tLSkY_fmVYOWdgeBBxBGscfAoCDFISCnxBHUZqfGNbYm5rLhJ-HA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "test1") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		$b  = "LF8FUh5GC3tLSkY_fmVYOWdgeBBxBGscfAoCDFISCnxBHUZqfGNbYm5rLhJ-HA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "test2") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		$b  = "LF8FUh5BWX9CSUM8fjdePDNqKhRwVWIdKVBUVlFFXi8RSkZrdDBeP2drekN_HA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "free1") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPN	
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		$b  = "LF8FUh5BWX9CSUM8fjdePDNqKhRwVWIdKVBUVlFFXi8RSkZrdDBeP2drekN_HA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "free2") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPN	
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		$b  = "LF8FUh5GCX4RGEQ8eGcObW4xexQlBGIacgtVUFESWn5DGEVqdTMOaGRkfEQiHA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "anon1") {
			# NO AP LOGIN
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
		}

		$b  = "LF8FUh4XXHpAHxJveGZSbWdjfkEnUDBJfAcCB1VDWihGTUBse2UMPjNiL0IiHA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "administrator") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only WEP	
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		$b  = "LF8FUh5HCyoRTkFgfDUMaGJqfRUjAjZOK1ZTAAdHXy1GG05oejIPPjFlLhV0HA==";
    	$flag = decode($b, $a);
		#relay user
		if ($_SESSION["Username"] == "CONTOSOREG\luis.da") { # RELAY
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
			echo "<br><br>";
			echo "<br><br>";
		}

		$b  = "LF8FUh5EWyxDTBNodGcOYjZrdRV3BzZLeFZTAAEVCS0WGhE9eWIPazVneUl-HA==";
    	$flag = decode($b, $a);
		if ($_SESSION["Username"] == "CORPO\god") { # RELAY creds stolen in responder in regional network
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.7.') !== false) { //only WEP	
			      echo "Flag: <button onclick=\"copyFlagToClipboard('$flag')\">$flag</button>";
				echo "<br><br>";
				echo "<br><br>";
				echo "<br><br>";
				echo "AP CONFIG:";
				echo "<br><br>";
				echo "
		eap_user_file=/root/mgt/hostapd_wpe.eap_user<br>
		ca_cert=/root/certs/ca.crt<br>
		server_cert=/root/certs/server.crt<br>
		private_key=/root/certs/server.key<br>
		private_key_passwd=whatever<br>
		dh_file=/etc/hostapd-wpe/dh<br>
		<br>
		# 802.11 Options<br>
		ssid=wifi-corp<br>
		channel=44<br>";
				echo "Certificate Authority:  <a href=\"/.internalCA/\"> http://", $_SERVER['SERVER_ADDR'], "/.internalCA/ </a>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}



		echo "<br><br>";
		?>

		Congratulation! You have logged into password protected page. <a href="logout.php">Click here</a> to Logout.

	</div>
</body>

</html>