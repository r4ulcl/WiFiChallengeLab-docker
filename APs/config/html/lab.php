<?php
// Start the session
session_start();

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

    ?>

    Congratulation! You have logged into password protected page. <a href="index.php">Click here</a> to go to index.php to get the flag.

</body>

</html>