<?php
function OpenCon() {
    $dbhost = "192.168.1.3";
    $dbuser = "webuser";
    $dbpass = ""; // contraseña vacía
    $dbname = "flights";

    $ssl_ca   = "/etc/ssl/certs/airport_web/ca-cert.pem";
    $ssl_cert = "/etc/ssl/certs/airport_web/client-cert.pem";
    $ssl_key  = "/etc/ssl/certs/airport_web/client-key.pem";

    $conn = mysqli_init();

    if (!$conn) {
        die("No se pudo inicializar MySQLi");
    }

    mysqli_ssl_set($conn, $ssl_key, $ssl_cert, $ssl_ca, null, null);

    if (!mysqli_real_connect($conn, $dbhost, $dbuser, $dbpass, $dbname, 3306, null, MYSQLI_CLIENT_SSL | MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT)) {
        die("Error de conexión SSL MySQL/MariaDB: " . mysqli_connect_error());
    }

    return $conn;
}
?>