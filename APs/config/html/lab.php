<?php session_start(); /* Starts the session */
if(!isset($_SESSION['UserData']['Username'])){
header("location:login.php");
exit;
}
?>

<?php
echo "Welcome ", $_SESSION["Username"];
echo "<br><br>";
echo "<br><br>";

?>

Congratulation! You have logged into password protected page. <a href="index.php">Click here</a> to go to index.php to get the flag. 

