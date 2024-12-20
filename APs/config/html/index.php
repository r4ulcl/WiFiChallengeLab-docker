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
		echo "Welcome ", $_SESSION["Username"];
		echo "<br><br>";
		echo "<br><br>";

		if ($_SESSION["Username"] == "GLOBAL\GlobalAdmin") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false) { //only TLS	
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{948e68a05011d8733b6e80300538c6abcdc20ebd}')\">flag{948e68a05011d8733b6e80300538c6abcdc20ebd}</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == "CONTOSO\Administrator") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT 1
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{04e474a4826cf10ba9f60da7ce07105ea2716aac}')\">flag{04e474a4826cf10ba9f60da7ce07105ea2716aac}</button>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT	2
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{04e474a4826cf10ba9f60da7ce07105ea2716aac}')\">flag{04e474a4826cf10ba9f60da7ce07105ea2716aac}</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == "admin") {


			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT Relay	
				echo "Hello";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only wep
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{c342fe657870020a1b164f2075f447564fdd1c3d}')\">flag{c342fe657870020a1b164f2075f447564fdd1c3d}</button>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.3.') !== false) { //only WPS
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{850e63f13f6c5e9a423670671a08b912c78fadc9}')\">flag{850e63f13f6c5e9a423670671a08b912c78fadc9}</button>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.16.') !== false) { //only WPS
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{680efaa62f7e953c24667285173711bc6bb6d3ff}')\">flag{680efaa62f7e953c24667285173711bc6bb6d3ff}</button>";
			} else {
				echo "No FLAG, try logging in with another user ;)";
			}
		}

		#ALL: and strpos($_SERVER['REMOTE_ADDR'], '192.168.X.') !== false to only use users in each network

		if ($_SESSION["Username"] == "CONTOSO\juan.tr") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{3407a6e0ad77965731da8357c4270ecce8b642e4}')\">flag{3407a6e0ad77965731da8357c4270ecce8b642e4}</button>";
				echo "<br><br>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT	2
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{3407a6e0ad77965731da8357c4270ecce8b642e4}')\">flag{3407a6e0ad77965731da8357c4270ecce8b642e4}</button>";
				echo "<br><br>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == 'CONTOSO\test') {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT 1
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{14ddfbfcc90f80bd40287537d19b0aefdb5a0058}')\">flag{14ddfbfcc90f80bd40287537d19b0aefdb5a0058}</button>";
				echo "<br><br>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT	2
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{14ddfbfcc90f80bd40287537d19b0aefdb5a0058}')\">flag{14ddfbfcc90f80bd40287537d19b0aefdb5a0058}</button>";
				echo "<br><br>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == 'CONTOSO\ftp') {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{004b3aef9bbbf24cdd55a4e13e384a40dc996848}')\">flag{004b3aef9bbbf24cdd55a4e13e384a40dc996848}</button>";
				echo "<br><br>";
			} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT	2
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{004b3aef9bbbf24cdd55a4e13e384a40dc996848}')\">flag{004b3aef9bbbf24cdd55a4e13e384a40dc996848}</button>";
				echo "<br><br>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == "test1") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{2d5931f342c034a7e9d69f97fe23d13121898bc8}')\">flag{2d5931f342c034a7e9d69f97fe23d13121898bc8}</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == "test2") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{2d5931f342c034a7e9d69f97fe23d13121898bc8}')\">flag{2d5931f342c034a7e9d69f97fe23d13121898bc8}</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == "free1") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPN	
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{561004e3f4fd9fe640ecc0c411ac3129a4e08629}')\">flag{561004e3f4fd9fe640ecc0c411ac3129a4e08629}</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == "free2") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPN	
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{561004e3f4fd9fe640ecc0c411ac3129a4e08629}')\">flag{561004e3f4fd9fe640ecc0c411ac3129a4e08629}</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		if ($_SESSION["Username"] == "anon1") {
			# NO AP LOGIN
			echo "Flag: <button onclick=\"copyFlagToClipboard('flag{2f0ca3e56d79b7ece0b881e4f501a238bd23705d}')\">flag{2f0ca3e56d79b7ece0b881e4f501a238bd23705d}</button>";
		}

		if ($_SESSION["Username"] == "administrator") {
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only WEP	
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{c342fe657870020a1b164f2075f447564fdd1c3d}')\">flag{c342fe657870020a1b164f2075f447564fdd1c3d}</button>";
			} else {
				echo "Your Princess Is in Another Castle!";
			}
		}

		#relay user
		if ($_SESSION["Username"] == "CONTOSOREG\luis.da") { # RELAY
			echo "Flag: <button onclick=\"copyFlagToClipboard('flag{3ddc7691df2591decd6ae75b30c4b917cedf6bd2}')\">flag{3ddc7691df2591decd6ae75b30c4b917cedf6bd2}</button>";
			echo "<br><br>";
			echo "<br><br>";
		}

		if ($_SESSION["Username"] == "CORPO\god") { # RELAY creds stolen in responder in regional network
			if (strpos($_SERVER['REMOTE_ADDR'], '192.168.7.') !== false) { //only WEP	
				echo "Flag: <button onclick=\"copyFlagToClipboard('flag{04b15d196d8a89d1fd32e75dafcdcfd43e1b4588}')\">flag{04b15d196d8a89d1fd32e75dafcdcfd43e1b4588}</button>";
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