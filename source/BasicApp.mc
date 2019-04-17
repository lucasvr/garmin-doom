using Toybox.Application as App;

class BasicApp extends App.AppBase {

    function initialize() {
        App.AppBase.initialize();
    }

    //! onStart() is called on application start up
    function onStart(state) {
    }

    //! onStop() is called when your application is exiting
    function onStop(state) {
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ new BasicView() ];
    }

}
