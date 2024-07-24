<?php

// Check if user is already logged in
if (isset($_SESSION['UserData']['Username'])) {
  header("Location: index.php"); // Redirect to index.php
  exit; // Make sure to exit after redirection
}

session_start(); /* Starts the session */


/* Check Login form submitted */
if (isset($_POST['Submit'])) {
  /* Define username and associated password array */
  $logins = array(
    'GLOBAL\GlobalAdmin' => 'SuperSuperSecure@!@',
    'CONTOSO\Administrator' => 'SuperSecure@!@',
    'CONTOSO\juan.tr' => 'bulldogs1234',
    'CONTOSO\test' => 'monkey',
    'CONTOSO\ftp' => '12345678',
    'CONTOSOREG\luis.da' => 'u89gh68!6fcv56ed',
    'CORPO\god' => 'tommy1',
    'admin' => 'admin',
    'test1' => 'OYfDcUNQu9PCojb',
    'test2' => '2q60joygCBJQuFo',
    'free1' => 'Jyl1iq8UajZ1fEK',
    'free2' => '5LqwwccmTg6C39y',
    'administrator' => '123456789a',
    'anon1' => 'CRgwj5fZTo1cO6Y'
  );


  /* Check and assign submitted Username and Password to new variable */
  $Username = isset($_POST['Username']) ? $_POST['Username'] : '';
  $Password = isset($_POST['Password']) ? $_POST['Password'] : '';

  /* Check Username and Password existence in defined array */
  if (isset($logins[$Username]) && $logins[$Username] == $Password) {
    /* Success: Set session variables and redirect to Protected page  */
    $_SESSION['UserData']['Username'] = $logins[$Username];
    /* Success: Set session variables USERNAME  */
    $_SESSION['Username'] = $Username;

    header("location:index.php");
    exit;
  } else {
    /*Unsuccessful attempt: Set error message */
    $msg = "<span style='color:red'>Invalid Login Details</span>";
  }
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
  /* Check IP from GLOBAL */
  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false) {
    session_start(); /* Starts the session */
    $Username = 'GLOBAL\GlobalAdmin';
    $Password = 'SuperSuperSecure@!@';
    $_SESSION['UserData']['Username'] = $Username;
    /* Success: Set session variables USERNAME  */
    $_SESSION['Username'] = $Username;
    echo "Router Login";

    header("location:index.php");
    exit;
  }

  # Check IP from CONTOSOREG Relay
  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.7.') !== false) {
    #relay user
    echo "<br><br>";
    echo "<br><br>";
    echo "flag{3ddc7691df2591decd6ae75b30c4b917cedf6bd2}";
    echo "<br><br>";
    echo "<br><br>";
  }

  # Check IP from CONTOSOREG Tablets Relay
  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.18.') !== false) {
    #relay user
    echo "<br><br>";
    echo "<br><br>";
    echo "flag{de9d7be205df3a9422b7fe054995aac57c41bdbb}";
    echo "<br><br>";
    echo "<br><br>";
  }

  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { #only WEP
    #relay user
    echo "<br><br>";
    echo "<br><br>";
    echo "flag{c342fe657870020a1b164f2075f447564fdd1c3d}";
    echo "<br><br>";
    echo "<br><br>";
  }

  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.14.') !== false) { #only SAE management
    #relay user
    echo "<br><br>";
    echo "<br><br>";
    echo "flag{a192e7909455cb1ffd1d2355e70e2ef0f4ccc811}";
    echo "<br><br>";
    echo "<br><br>";
  }

  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.15.') !== false) { #only SAE IT
    #relay user
    echo "<br><br>";
    echo "<br><br>";
    echo "flag{f4629b4c22636fa0ae72eb5d1cf9caf88b4ecbee}";
    echo "<br><br>";
    echo "<br><br>";
  }

  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false) { //only MGT TLS
    echo "<br><br>";
    echo "Hello Global Admin:";
    echo "<br><br>";
    echo "Your pass is: SuperSuperSecure@!@";
  }

  ?>


  <div class="content">

    <?php
    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPEN
      echo "<h3>Open Router Login</h3>";
    }

    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only WEP
      echo "<h3>WEP Router Login</h3>";
    }

    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK moviles
      echo "<h3>PSK Router Login</h3>";
    }
    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.3.') !== false) { //only WPS
      echo "<h3>WPS Router Login";
    }
    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.4.') !== false) { //only krack
      echo "<h3>krack Router Login</h3>";
    }

    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT
      echo "<h3>Corp Router Login</h3>";
    }

    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.7.') !== false) { //only MGT Relay
      echo "<h3>Regional Router Login</h3>";
    }

    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.18.') !== false) { //only MGT Relay
      echo "<h3>Regional Tablets Router Login</h3>";
    }

    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false) { //only ENTERPRISE
      echo "<h3>Global Router Login</h3>";
    }

    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.16.') !== false) { //only ENTERPRISE
      echo "<h3>Wifi free Login</h3>";
    }

    ?>
    <form action="" method="post" name="Login_Form">
      <table width="400" border="0" align="center" cellpadding="5" cellspacing="1" class="Table">
        <?php if (isset($msg)) { ?>
          <tr>
            <td colspan="2" align="center" valign="top">
              <?php echo $msg; ?>
            </td>
          </tr>
        <?php } ?>
        <tr>
          <td colspan="2" align="left" valign="top">
            <h3>Login</h3>
          </td>
        </tr>
        <tr>
          <td align="right" valign="middle">Username</td>
          <td><input name="Username" type="text" class="Input"></td>
        </tr>
        <tr>
          <td align="right" valign="middle">Password</td>
          <td><input name="Password" type="password" class="Input"></td>
        </tr>
        <tr>
          <td></td>
          <td><input name="Submit" type="submit" value="Login" class="Button3"></td>
        </tr>
      </table>
    </form>
  </div>
</body>

</html>