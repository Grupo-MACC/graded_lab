<?php
include 'db_connection.php';
$conn = OpenCon();
$actual_link = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://$_SERVER[HTTP_HOST]$_SERVER[REQUEST_URI]";


function generateTableFromResult($result) {
   $actual_link = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://$_SERVER[HTTP_HOST]";
   $html = '<table class="table table-striped">';
   while($row = mysqli_fetch_array($result, MYSQLI_ASSOC)) {
        $html.="<tr>";
	$html.="<td><a href='".$actual_link."/index.php?flight=".$row['FLIGHT_CODE']."'>".$row['FLIGHT_CODE']."</a></td>";
        $html.="<td>".$row['SOURCE']."</td>";
        $html.="<td>".$row['DESTINATION']."</td>";
        $html.="<td>".$row['ARRIVAL']."</td>";
        $html.="<td>".$row['DEPARTURE']."</td>";
        $html.="<td>".$row['STATUS']."</td>";
        $html.="<td>".$row['DURATION']."</td>";
        $html.="<td>".$row['FLIGHTTYPE']."</td>";
        $html.="<td>".$row['AIRLINED']."</td>";
        $html.="</tr>\n\r";
   }
   $html.="</table>";
   return $html;
}

?>

<body>
<head>
  <link rel="stylesheet" type="text/css" href="./css/css.css">
  <link rel="stylesheet" href="./css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" crossorigin="anonymous">
</head>
<video autoplay muted loop id="myVideo">
  <source src="./connections.mp4" type="video/mp4">
</video>

<!-- Optional: some overlay text to describe the video -->
<div class="content">
<?php 

    if(!isset($_GET['flight']))
    {
      $query = "SELECT * FROM FLIGHT LIMIT 10";
    } else { 
      $flightid = $_GET['flight'];
      $flightid = "$flightid";
      $query = "SELECT * FROM FLIGHT WHERE FLIGHT_CODE = '$flightid'";
    }


$result = mysqli_query($conn,$query) or die(mysqli_error());


echo generateTableFromResult($result); 

?>

</div>
</body>
