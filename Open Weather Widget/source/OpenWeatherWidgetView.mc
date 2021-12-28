using Toybox.Activity;
using Toybox.Time;
using Toybox.Graphics as G;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Communications as Comms;
using Toybox.Application as App;
using Toybox.Position;

class OpenWeatherWidgetView extends Ui.View {

	var W;
	var H;
	var iconsFont;
	var screenNum = 1;
	var gpsRequested = false;

	var updateTimer = new Timer.Timer();
	var settingsArr = $.getSettings();

	var iconsDictionary = {
		"01d" => Rez.Drawables.d01,
		"01n" => Rez.Drawables.n01,
		"02d" => Rez.Drawables.d02,
		"02n" => Rez.Drawables.n02,
		"03d" => Rez.Drawables.d03,
		"03n" => Rez.Drawables.n03,
		"04d" => Rez.Drawables.d04,
		"04n" => Rez.Drawables.n04,
		"09d" => Rez.Drawables.d09,
		"09n" => Rez.Drawables.n09,
		"10d" => Rez.Drawables.d10,
		"10n" => Rez.Drawables.n10,
		"11d" => Rez.Drawables.d11,
		"11n" => Rez.Drawables.n11,
		"13d" => Rez.Drawables.d13,
		"13n" => Rez.Drawables.n13,
		"50d" => Rez.Drawables.d50,
		"50n" => Rez.Drawables.n50
	};
	
    function initialize() {
        View.initialize();
    }

    function updateSettings() {
    	settingsArr = $.getSettings();
	}

    // Load your resources here
    function onLayout(dc as Dc) as Void {
    	W = dc.getWidth();
    	H = dc.getHeight();
    	
    	iconsFont = WatchUi.loadResource(Rez.Fonts.owm_font);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    	//$.p("View onShow");
    	updateTimer.start(method(:onTimerUpdate), 10000, true);
    }

    function onHide() as Void {
    	//$.p("View onHide");
    	updateTimer.stop();
    }
	
    function onTimerUpdate() {
    	Ui.requestUpdate();
    }
 
    function startGPS() {
        $.p("startGPS");
        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
        gpsRequested = true;
        WatchUi.requestUpdate();
    }

    function onPosition(info) {
        $.p("onPosition");
        if (info == null || info.position == null) {return;}
        $.saveLocation(info.position.toDegrees());
        WatchUi.requestUpdate();
        $.makeOWMwebRequest(false);
	}

    // Update the view
    function onUpdate(dc as Dc) as Void {
        View.onUpdate(dc);
        
        // Set anti-alias if available
        if (G.Dc has :setAntiAlias) {dc.setAntiAlias(true);}
        
    	dc.setColor(0, G.COLOR_BLACK);
        dc.clear();
       
        // Retrieve weather data
        var weatherData = App.Storage.getValue("weather");
        
        var errorMessage = "";
        
        var apiKey = App.Properties.getValue("api_key");
		if (apiKey == null || apiKey.length() == 0) {
        	errorMessage = R(Rez.Strings.NoAPIkey);
        } else if (App.Storage.getValue("last_location") == null) {
        	if (gpsRequested) {errorMessage = R(Rez.Strings.WaitForGPS);}
        	else {errorMessage = R(Rez.Strings.NoLocation);}
        } else if (weatherData == null) {
        	errorMessage = R(Rez.Strings.NoData);
        } else if (weatherData[0] == 401) {
        	errorMessage = R(Rez.Strings.InvalidKey);
        } else if (weatherData[0] == 404) {
        	errorMessage = R(Rez.Strings.InvalidLocation);
        } else if (weatherData[0] == 429) {
        	errorMessage = R(Rez.Strings.SuspendedKey);
        } else if (weatherData[0] != 200) {
        	errorMessage = R(Rez.Strings.OWMerror) + " " + weatherData[0];
        } else if (weatherData.size() < 17) {
        	errorMessage = R(Rez.Strings.InvalidData);
        }
        
		// Display error message
        if (errorMessage.length() > 0) {
        
        	drawStr(dc, 50, 50, G.FONT_SYSTEM_SMALL, G.COLOR_WHITE, errorMessage, G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);

			var iqImage = Ui.loadResource(Rez.Drawables.LauncherIcon);
			dc.drawBitmap(W/2 - (iqImage.getWidth() / 2), 5, iqImage);

        	return;
        }
        
        // Display Weather. weatherData array structure:
        
		// 1 - Condition ID (800)
		// 2 - Condition Group text ("Clear")
		// 3 - Condition description ("clear sky")
		// 4 - Icon ("01n")
		// 5 - Location name ("Olathe")
		// 6 - Location country ("US")
		// 7 - date (1639535620)
		// 8 - sunrise (1639488608)
		// 9 - sunset (1639522685)
		// 10- temp (14.420000)
		// 11- feels like (14.420000)
		// 12- humidity (89)
		// 13- pressure (1013)
		// 14- wind speed (1.790000)
		// 15- wind gusts (1.790000)
		// 16- wind degree (186)
		
		// Verify OWM data
		if (weatherData[7] == null) {weatherData[7] = Time.now().value();}
		if (weatherData[10] == null) {weatherData[10] = 0;}
		if (weatherData[11] == null) {weatherData[11] = weatherData[10];}
		if (weatherData[12] == null) {weatherData[12] = 0;}
		if (weatherData[13] == null) {weatherData[13] = 0;}
		if (weatherData[14] == null) {weatherData[14] = 0;}
		if (weatherData[15] == null) {weatherData[15] = weatherData[14];}
		if (weatherData[16] == null) {weatherData[16] = 0;}
		
		var weatherImage;
		var str = "";
		
		if (iconsDictionary.get(weatherData[4]) != null) {weatherImage = Ui.loadResource(iconsDictionary.get(weatherData[4]));}
		else {weatherImage = Ui.loadResource(Rez.Drawables.iq_icon);}

		// Temperature
		str = (settingsArr[2] ? weatherData[10].format("%.0f") : celsius2fahrenheit(weatherData[10]).format("%.0f")); //+ $.DEGREE_SYMBOL;
       	drawStr(dc, 50, 15, G.FONT_SYSTEM_NUMBER_MEDIUM, 0xFFFF00, str, G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
       	drawStr(dc, str.length() > 2 ? 75 : 67, 15, G.FONT_SYSTEM_SMALL, 0xFFFF00, settingsArr[3], G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
       	
		// Feels like
		str = "~ " + (settingsArr[2] ? weatherData[11].format("%.0f") : celsius2fahrenheit(weatherData[11]).format("%.0f")) + settingsArr[3];
       	drawStr(dc, 15, 30, G.FONT_SYSTEM_SMALL, G.COLOR_LT_GRAY, str, G.TEXT_JUSTIFY_LEFT | G.TEXT_JUSTIFY_VCENTER);

		if (screenNum == 1) {
			// Humidity
			str = weatherData[12].format("%.0f") + "%";
	       	drawStr(dc, 66, 30, G.FONT_SYSTEM_SMALL, G.COLOR_LT_GRAY, str, G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
	       	drawStr(dc, 81, 30, iconsFont, G.COLOR_LT_GRAY, "\uF078", G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
	    } else {
			// Pressure
			str = weatherData[13].format("%.0f");
	       	drawStr(dc, 66, 30, G.FONT_SYSTEM_SMALL, G.COLOR_LT_GRAY, str, G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
	       	drawStr(dc, 81, 30, iconsFont, G.COLOR_LT_GRAY, "\uF079", G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
	    }

       	// Condition
       	dc.setColor(G.COLOR_BLUE, G.COLOR_BLUE);
       	//dc.fillRoundedRectangle(W * 2 / 100 + 3, H * 47 / 100 - 22, 44, 44, 10);
       	dc.drawBitmap(W * 0 / 100, H * 47 / 100 - 25, weatherImage);
       	str = $.capitalize(weatherData[3]);
       	if (str.length() > 12) {
	       	drawStr(dc, 19, 47, G.FONT_SYSTEM_MEDIUM, G.COLOR_WHITE,str, G.TEXT_JUSTIFY_LEFT | G.TEXT_JUSTIFY_VCENTER);
       	} else {
       		drawStr(dc, 50, 47, G.FONT_SYSTEM_MEDIUM, G.COLOR_WHITE,str, G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
       	}

		// Time and location
		var t = (Time.now().value() - weatherData[7]) / 60;
		t = t < 0 ? 0 : t;
		str = t.format("%.0f") + " min, " + weatherData[5];
       	drawStr(dc, 50, 61, G.FONT_SYSTEM_SMALL, G.COLOR_LT_GRAY, str.substring(0, 21), G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
		
		// Wind
		str = (weatherData[14] * settingsArr[0]).format(settingsArr[4] == 4 ? "%.1f" : "%.0f") + " / " + (weatherData[15] * settingsArr[0]).format(settingsArr[4] == 4 ? "%.1f" : "%.0f") + " " + settingsArr[1];
       	drawStr(dc, 50, 78, G.FONT_SYSTEM_SMALL, G.COLOR_WHITE, str, G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
       	drawStr(dc, 15, 78, iconsFont, G.COLOR_LT_GRAY, "\uF050", G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);

		// Wind direction
		str = weatherData[16].format("%.0f") + $.DEGREE_SYMBOL + " " + $.windDegreeToName(weatherData[16]);
       	drawStr(dc, 50, 90, G.FONT_SYSTEM_SMALL, G.COLOR_LT_GRAY, str, G.TEXT_JUSTIFY_CENTER | G.TEXT_JUSTIFY_VCENTER);
       	
       	// Lines
       	dc.setColor(G.COLOR_DK_GRAY, G.COLOR_DK_GRAY);
       	dc.drawLine(0, H * 38 / 100, W, H * 38 / 100);
       	dc.drawLine(0, H * 70 / 100, W, H * 70 / 100);
    }
    
    // Draws string with all parameters in 1 call. 
    // X and Y are specified in % of screen size
    function drawStr(dc, x, y, font, color, str, alignment) {
    	dc.setColor(color, G.COLOR_TRANSPARENT);
    	dc.drawText(W * x / 100, H * y / 100, font, str, alignment);
    }
}
