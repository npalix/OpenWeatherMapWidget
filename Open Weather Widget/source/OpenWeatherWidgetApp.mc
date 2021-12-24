using Toybox.Application as App;
using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
using Toybox.Time;

(:background)
class OpenWeatherWidgetApp extends App.AppBase {

	var mainView = null;
	
    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as Array<Views or InputDelegates>? {
    	//$.p("getInitialView");
    	mainView = new OpenWeatherWidgetView();
	    	
    	// Check for glances. Don't re-do settings and Weather event if enabled
    	var glanceMode = Sys.DeviceSettings has :isGlanceModeEnabled && Sys.getDeviceSettings().isGlanceModeEnabled;
    	if (!glanceMode) {
	    	setWeatherEvent();
    	}
        return [ mainView, new OpenWeatherWidgetDelegate(mainView) ] as Array<Views or InputDelegates>;
    }

    // Called when the application settings have been changed by Garmin Connect Mobile
    function onSettingsChanged() {
    	//$.p("onSettingsChanged");
    	if (mainView != null) {mainView.updateSettings();}
    	setWeatherEvent();
    	Ui.requestUpdate();
	}

	function getServiceDelegate() {
		return [new BackgroundService()];
	}

    function getGlanceView() {
    	//$.p("getGlanceView");
    	setWeatherEvent();
        return [new OpenWeatherGlancetView()];
    }

	function onBackgroundData(data) {
		//$.p(data);
		// Process only if no BLE error
		if (data[0] > 0) {
			Application.Storage.setValue("weather", data);
			Ui.requestUpdate();
		}
	}
	
	function setWeatherEvent() {
		// If location is not obtained yet, do not run OWM
		if ($.getLocation() == null) {return;}
		// If API key is not set, do not run OWM
		var apiKey = App.Properties.getValue("api_key");
		if (apiKey == null || apiKey.length() == 0) {return;}
		
		// Check if API key was invalid. Connect to OWM immediatelly if it was
		var weatherData = App.Storage.getValue("weather");
		var invalidKey = false;
		if (weatherData != null && weatherData[0] == 401) {invalidKey = true;}
		
    	var rate = Application.Properties.getValue("refresh_rate");
    	rate = rate == null ? 0 : rate;
    	if (rate == 0 || invalidKey) {
    		Bg.deleteTemporalEvent();
    		$.makeOWMwebRequest(false);
    	}
    	else {Bg.registerForTemporalEvent(new Time.Duration(rate * 60));}
	}
}

function getApp() as OpenWeatherWidgetApp {
    return App.getApp() as OpenWeatherWidgetApp;
}

