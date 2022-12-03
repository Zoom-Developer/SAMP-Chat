<?php
    require 'config.php';
    $conn = new mysqli($MYSQL_HOST, $MYSQL_USER, $MYSQL_PASSWORD, $MYSQL_DATABASE);

    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }
    $server = $_GET['server'];
    if (!empty($server)) $players = $conn->query("SELECT `name`, `x`, `y`, `server`, `ip`, `in_int` FROM `users` WHERE `online` > 0 and `ip` = '$server' and `server` != 'SA-MP'")->fetch_all(MYSQLI_ASSOC);
    else $players = $conn->query("SELECT `ip`, `server` FROM `users` WHERE `online` > 0 and `ip` and `server` != 'SA-MP'")->fetch_all(MYSQLI_ASSOC);
    
?>

<!DOCTYPE html>
<html lang="ru">
    <head>
        <meta charset="UTF-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Josefin+Sans:wght@700&display=swap" rel="stylesheet">
        <title>Diablo & Smit Map</title>
        <style>
            body {
                background-color: black;
                color: white;
                font-family: 'Josefin Sans', sans-serif;
                text-align: center;
            }
            .servers {
                margin-top: 15%;
            }
            a {
                color: aquamarine;
            }
        </style>
    </head>
    <body>
        <?php 
            if (empty($server)) {
                $servers = [];
                foreach ($players as $ply)
                {
                    if (!isset($servers[$ply['ip']])) {
                        $servers[$ply['ip']] = $ply['server'];
                    }
                }
                echo "<div class='servers'>";
                foreach ($servers as $ip => $name)
                {
                    echo "<a href='./?server=$ip'>".$name."</a><br>";
                }
                if (!$servers) echo "<span>No servers</span>";
                echo "</div>";
                die();
            }
            else {
                $server_name = $players[0]['server'];
                echo "<script>const players = ".json_encode($players)."</script>"; 
            }
        ?>
        <center>
            <h1><?php echo $server_name . " ($server)"?></h1>
            <a href="./">< Вернуться к списку серверов</a><br><br>
            <canvas id="map"></canvas>
        </center>
        <script src="js/main.js"></script>
        <script src="js/map.js"></script>
    </body>
</html>