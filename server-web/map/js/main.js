var buttons = [];

function getMousePos(canvas, event) {
    var rect = canvas.getBoundingClientRect();
    return {
        x: event.clientX - rect.left,
        y: event.clientY - rect.top
    };
}

function isInside(pos, rect){
    return pos.x > rect.x && pos.x < rect.x+rect.width && pos.y < rect.y+rect.height && pos.y > rect.y
}

function samp2web(x, y)
{
    x = canvas.width / 2 + x * 0.12
    y = canvas.width / 2 + y * -0.1325
    return [x, y]
}


function create_player(name, x, y, in_int)
{
    var canvas = document.getElementById("map");
    var ctx = canvas.getContext('2d');
    var marker = new Image();
    if (in_int == "0") marker.src = "img/marker.png";
    else marker.src = "img/marker_yellow.png";
    marker.onload = function() {
        vector = samp2web(x, y)
        ctx.drawImage(marker, vector[0], vector[1], 10, 10);
        ctx.fillStyle = "white";
        ctx.font = "13px sans-serif Josefin Sans";
        ctx.textAlign = "center";
        ctx.fillText(name, vector[0], vector[1] + 20)
    }
}