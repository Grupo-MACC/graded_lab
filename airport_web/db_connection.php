<?php

function OpenCon()
 {
 $dbhost = "127.0.0.1";
 $dbuser = "root";
 $dbpass = "root";
 $dbname = "flights";
 $conn = mysqli_connect($dbhost, $dbuser, $dbpass);

if (!$conn) {
  die('Could not connect: ' . mysql_error());
}
mysqli_select_db ($conn,$dbname);
 
 return $conn;
 }
 
function CloseCon($conn)
 {
 $conn -> close();
 }
   
?>
