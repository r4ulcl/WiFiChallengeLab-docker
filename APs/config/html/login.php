<?php session_start(); /* Starts the session */


/* Check Login form submitted */if(isset($_POST['Submit'])){
/* Define username and associated password array */$logins = array(
'GLOBAL\GlobalAdmin' => 'SuperSuperSecure@!@',
'CONTOSO\Administrator' => 'SuperSecure@!@',
'CONTOSO\juan.tr' => 'bulldogs1234',
'CONTOSOREG\luis.da' => 'u89gh68!6fcv56ed',
'CORPO\god' => 'tommy1',
'admin' => 'admin',
'test1' => 'OYfDcUNQu9PCojb',
'test2' => '2q60joygCBJQuFo',
'free1' => 'Jyl1iq8UajZ1fEK',
'free2' => '5LqwwccmTg6C39y',
'administrator' => '123456789a',
'anon1' => 'CRgwj5fZTo1cO6Y');


/* Check and assign submitted Username and Password to new variable */$Username = isset($_POST['Username']) ? $_POST['Username'] : '';
$Password = isset($_POST['Password']) ? $_POST['Password'] : '';

/* Check Username and Password existence in defined array */if (isset($logins[$Username]) && $logins[$Username] == $Password){
/* Success: Set session variables and redirect to Protected page  */$_SESSION['UserData']['Username']=$logins[$Username];
/* Success: Set session variables USERNAME  */$_SESSION['Username']=$Username;

header("location:index.php");
exit;
} else {
/*Unsuccessful attempt: Set error message */$msg="<span style='color:red'>Invalid Login Details</span>";
}
}


if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPEN
  echo "<br><br>";
  echo "Open Router Login";
  echo "<br><br>";
}

if (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only WEP
  echo "<br><br>";
  echo "WEP Router Login";
  echo "<br><br>";
}

if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK moviles
  echo "<br><br>";
  echo "PSK Router Login";
  echo "<br><br>";
}
if (strpos($_SERVER['REMOTE_ADDR'], '192.168.3.') !== false) { //only WPS
  echo "<br><br>";
  echo "WPS Router Login";
  echo "<br><br>";
}
if (strpos($_SERVER['REMOTE_ADDR'], '192.168.4.') !== false) { //only krack
  echo "<br><br>";
  echo "krack Router Login";
  echo "<br><br>";
}

if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT
  echo "<br><br>";
  echo "Corp Router Login";
  echo "<br><br>";
}

if (strpos($_SERVER['REMOTE_ADDR'], '192.168.7.') !== false) { //only MGT Relay
  echo "<br><br>";
  echo "Regional Router Login";
  echo "<br><br>";
}

if (strpos($_SERVER['REMOTE_ADDR'], '192.168.18.') !== false) { //only MGT Relay
  echo "<br><br>";
  echo "Regional Tablets Router Login";
  echo "<br><br>";
}

if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false) { //only ENTERPRISE
  echo "<br><br>";
  echo "Global Router Login";
  echo "<br><br>";
}

if (strpos($_SERVER['REMOTE_ADDR'], '192.168.16.') !== false) { //only ENTERPRISE
  echo "<br><br>";
  echo "Wifi free Login";
  echo "<br><br>";
}


?>

<?php
  /* Check IP from GLOBAL */
  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false){
    session_start(); /* Starts the session */
    $Username = 'GLOBAL\GlobalAdmin';
    $Password = 'SuperSuperSecure@!@';
    $_SESSION['UserData']['Username']=$Username;
    /* Success: Set session variables USERNAME  */$_SESSION['Username']=$Username;
    echo "Router Login";

    header("location:index.php");
    exit;
  }

  # Check IP from CONTOSOREG Relay
  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.7.') !== false){
    #relay user
    echo "<br><br>";
    echo "<br><br>";
    echo "flag{NBLvyxgwckKnyGup6HNj}";
    echo "<br><br>";
    echo "<br><br>";
  }

  # Check IP from CONTOSOREG Tablets Relay
  if (strpos($_SERVER['REMOTE_ADDR'], '192.168.18.') !== false){
    #relay user
    echo "<br><br>";
    echo "<br><br>";
    echo "flag{gsnyT98GxngXgMPJEIKw}";
    echo "<br><br>";
    echo "<br><br>";
  }
?>

<form action="" method="post" name="Login_Form">
  <table width="400" border="0" align="center" cellpadding="5" cellspacing="1" class="Table">
    <?php if(isset($msg)){?>
    <tr>
      <td colspan="2" align="center" valign="top"><?php echo $msg;?></td>
    </tr>
    <?php } ?>
    <tr>
      <td colspan="2" align="left" valign="top"><h3>Login</h3></td>
    </tr>
    <tr>
      <td align="right" valign="top">Username</td>
      <td><input name="Username" type="text" class="Input"></td>
    </tr>
    <tr>
      <td align="right">Password</td>
      <td><input name="Password" type="password" class="Input"></td>
    </tr>
    <tr>
      <td> </td>
      <td><input name="Submit" type="submit" value="Login" class="Button3"></td>
    </tr>
  </table>
</form>

<?php
if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false) { //only MGT TLS
    echo "<br><br>";
    echo "Hello Global Admin:";
    echo "<br><br>";
    echo "Your pass is: SuperSuperSecure@!@";

  }
?>