extends Node2D

# Declare member variables here. Examples:
var zipCode = "32507";
var weatherApiKey = "15ae7c1d63b04b2c807467ac7288cdba";
#var wsUrl = "ws://pi:3000";
var wsUrl = "ws://192.168.15.188:3000";
#var wsUrl = "ws://localhost:3000";
#var wsUrl = "ws://apollo:3000";
var wsClient = WebSocketClient.new();

var connected = false;

# Called when the node enters the scene tree for the first time.
func _ready():
    # Handle weather events
    $HTTPRequest.connect("request_completed", self, "_on_request_completed")
    
    # Handle WS events
    wsClient.connect("connection_closed", self, "_ws_closed")
    wsClient.connect("connection_error", self, "_ws_closed")
    wsClient.connect("connection_established", self, "_ws_connected")
    # This signal is emitted when not using the Multiplayer API every time
    # a full packet is received.
    # Alternatively, you could check get_peer(1).get_available_packets() in a loop.
    wsClient.connect("data_received", self, "_ws_on_data")

    # Initial weather and WS connections
    initWs();
#    fetchWeather();

func initWs():
    # Initiate connection to the given URL.
    print("Connecting to websocket " + wsUrl);
    var err = wsClient.connect_to_url(wsUrl)
    if err != OK:
        print("Unable to connect to websocket " + wsUrl)
        set_process(false);
    else:
        connected = true;
    
func fetchWeather():
    var weatherUrl = "https://api.openweathermap.org/data/2.5/weather?zip="+zipCode+",US&appid="+weatherApiKey;
    $HTTPRequest.request(weatherUrl);

func _on_request_completed(result, response_code, headers, body):
    var json = JSON.parse(body.get_string_from_utf8())
    print(json.result)
    updateWeather(json.result.weather[0].description);
    
func _ws_closed(was_clean = false):
    # was_clean will tell you if the disconnection was correctly notified
    # by the remote peer before closing the socket.
    print("Closed, clean: ", was_clean)
    # set_process(false);
    connected = false;
    
    # Try Reconnecting
    yield(get_tree().create_timer(1.0), "timeout");
    initWs();

func _ws_connected(proto = ""):
    # This is called on connection, "proto" will be the selected WebSocket
    # sub-protocol (which is optional)
    print("Connected with protocol: ", proto)
    # You MUST always use get_peer(1).put_packet to send data to server,
    # and not put_packet directly when not using the MultiplayerAPI.
    wsClient.get_peer(1).put_packet("chat message".to_utf8())


func _ws_on_data():
    # Print the received packet, you MUST always use get_peer(1).get_packet
    # to receive data from server, and not get_packet directly when not
    # using the MultiplayerAPI.
    var data = wsClient.get_peer(1).get_packet().get_string_from_utf8()
    print("Got data from server: ", data);
    var json = JSON.parse(data)
    updateScreenData(json.result);

func _ws_process(delta):
    # Call this in _process or _physics_process. Data transfer, and signals
    # emission will only happen when calling this function.
    if ( connected ):
        wsClient.poll()

func updateWeather(current):
    var icon = "0";
    if ( current == 'clear sky' || current == 'few clouds' ):
        icon = "1";
    elif( current == 'shower rain' || current == 'mist'):
        icon = "3";
    elif( current == 'rain' ):
        icon = "4";
    elif( current == 'snow' ):
        icon = "5";
    elif( current == 'thunderstorm'):
        icon = "6";
    elif( current == 'scattered clouds' || current == 'broken clouds' ):
        icon = "9";
    else:
        icon = "1";
    print( "Weather is currently " + current + " (icon: " + icon + ")");
    $VContainer/HBoxContainer/CenterContainer/Weather.text = icon;
    
func updateScreenData(data):
    if ( ! data ):
        return;
    var time = data.time;
    var tPlus = false;
    var mins = "0";
    var sec = "0";
    
    # Figure if we are plus or minus
    if ( time < 0 ):
        tPlus = true;
        time = int( abs(time) );
        
    # Proceed with calculations
    if ( time < 60 ):
        mins = "0";
        sec = str(time);
        if ( time < 10 ):
            sec = "0" + sec;
    else:
        mins = str( floor( time / 60 ) );
        sec = str(int(time) % 60);
        if ( int(time) % 60 < 10 ):
            sec = "0" + sec;

    var lower = str(data.lower.replace('.',' ').replace(' ','!'));
    var upper = str(data.upper.replace('.',' ').replace(' ','!'));
    
    lower = padString(34,lower,'!');
    upper = padString(34,upper,'!');
    
    var tIndicator = "T-";
    if ( tPlus ):
        tIndicator = "!!";
    $VContainer/ClockContainer/Counter.text = tIndicator+mins+":"+sec;
        
    $VContainer/LowerContainer/LowerDisplay.text = "\n" + lower;
    $VContainer/UpperContainer/UpperDisplay.text = upper;
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    if ( connected ):
        wsClient.poll();

func padString(length, subject, pad):
    var padlen = ( length - subject.length() );
    var pre = floor(padlen / 2);
    var post = padlen-pre-1;
    var prePad = "";
    var postPad = "";
    for i in range(pre):
        prePad += pad;
    for i in range(post):
        postPad += pad;
    var result = prePad + subject + postPad;
    print('padding to ' + str(length) + ' and string is ' + str(result.length())); 
    print(result);
    return result;
