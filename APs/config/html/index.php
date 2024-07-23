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

	<?php
	echo "Welcome ", $_SESSION["Username"];
	echo "<br><br>";
	echo "<br><br>";

	if ($_SESSION["Username"] == "GLOBAL\GlobalAdmin") {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false) { //only TLS	
			echo "flag{948e68a05011d8733b6e80300538c6abcdc20ebd}";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	if ($_SESSION["Username"] == "CONTOSO\Administrator") {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
			echo "flag{04e474a4826cf10ba9f60da7ce07105ea2716aac}";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	if ($_SESSION["Username"] == "admin") {


		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT Relay	
			echo "Hello";
		} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only wep
			echo "flag{c342fe657870020a1b164f2075f447564fdd1c3d}";
		} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.3.') !== false) { //only WPS
			echo "flag{850e63f13f6c5e9a423670671a08b912c78fadc9}";
		} elseif (strpos($_SERVER['REMOTE_ADDR'], '192.168.16.') !== false) { //only WPS
			echo "flag{680efaa62f7e953c24667285173711bc6bb6d3ff}";
		} else {
			echo "No FLAG, try logging in with another user ;)";
		}
	}

	#ALL: and strpos($_SERVER['REMOTE_ADDR'], '192.168.X.') !== false to only use users in each network

	if ($_SESSION["Username"] == "CONTOSO\juan.tr") {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
			echo "flag{hGDSm8oltjM9q217iJYu}";
			echo "<br><br>";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	if ($_SESSION["Username"] == 'CONTOSO\test') {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
			echo "flag{14ddfbfcc90f80bd40287537d19b0aefdb5a0058}";
			echo "<br><br>";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	if ($_SESSION["Username"] == 'CONTOSO\ftp') {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
			echo "flag{004b3aef9bbbf24cdd55a4e13e384a40dc996848}";
			echo "<br><br>";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	if ($_SESSION["Username"] == "test1") {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
			echo "flag{2d5931f342c034a7e9d69f97fe23d13121898bc8}";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	if ($_SESSION["Username"] == "test2") {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
			echo "flag{2d5931f342c034a7e9d69f97fe23d13121898bc8}";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	if ($_SESSION["Username"] == "free1") {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPN	
			echo "flag{561004e3f4fd9fe640ecc0c411ac3129a4e08629}";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	if ($_SESSION["Username"] == "free2") {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPN	
			echo "flag{561004e3f4fd9fe640ecc0c411ac3129a4e08629}";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	if ($_SESSION["Username"] == "anon1") {
		# NO AP LOGIN
		echo "flag{2f0ca3e56d79b7ece0b881e4f501a238bd23705d}";
	}

	if ($_SESSION["Username"] == "administrator") {
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only WEP	
			echo "flag{c342fe657870020a1b164f2075f447564fdd1c3d}";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}

	#relay user
	if ($_SESSION["Username"] == "CONTOSOREG\luis.da") { # RELAY
		echo "flag{3ddc7691df2591decd6ae75b30c4b917cedf6bd2}";
		echo "<br><br>";
		echo "<br><br>";
	}

	if ($_SESSION["Username"] == "CORPO\god") { # RELAY creds stolen in responder in regional network
		if (strpos($_SERVER['REMOTE_ADDR'], '192.168.7.') !== false) { //only WEP	
			echo "flag{04b15d196d8a89d1fd32e75dafcdcfd43e1b4588}";
			echo "<br><br>";
			echo "<br><br>";
			echo "<br><br>";
			echo "AP CONFIG:";
			echo "<br><br>";
			echo "
		eap_user_file=/root/mgt/hostapd_wpe.eap_user<br>
		ca_cert=/root/mgt/certs/ca.crt<br>
		server_cert=/root/mgt/certs/server.crt<br>
		private_key=/root/mgt/certs/server.key<br>
		private_key_passwd=whatever<br>
		dh_file=/etc/hostapd-wpe/dh<br>
		<br>
		# 802.11 Options<br>
		ssid=wifi-corp<br>
		channel=6<br>";
			echo "Certificate Authority:  <a href=\"/.internalCA/\"> http://", $_SERVER['SERVER_ADDR'], "/.internalCA/ </a>";
		} else {
			echo "Your Princess Is in Another Castle!";
		}
	}




	echo "<br><br>";
	echo "<br><br>";
	?>

	Congratulation! You have logged into password protected page. <a href="logout.php">Click here</a> to Logout.

</body>

</html>