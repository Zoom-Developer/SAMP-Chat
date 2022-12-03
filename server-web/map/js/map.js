var canvas = document.getElementById("map");
var ctx = canvas.getContext('2d');
canvas.width = 800;
canvas.height = 800;
var map = new Image();
map.src = "img/map.webp";
map.onload = function() {
    ctx.drawImage(map, 0, 0, canvas.width, canvas.height);
    for (index = 0, len = players.length; index < len; ++index)
    {
        var player = players[index];
        create_player(player.name, +player.x, +player.y, player.in_int);
    }
    setInterval(() => window.location.reload(), 1000);
}