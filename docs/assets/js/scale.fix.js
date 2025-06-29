(function(document) {
    var metas = document.getElementsByTagName('meta'),
        changeViewportContent = function(content) {
            for (var i = 0; i < metas.length; i++) {
                if (metas[i].name == "viewport") {
                    metas[i].content = content;
                }
            }
        },
        initialize = function() {
            changeViewportContent("width=device-width, initial-scale=1.0, maximum-scale=1.0");
        },
        gestureStart = function() {
            changeViewportContent("width=device-width, initial-scale=1.0, maximum-scale=1.0");
        },
        gestureChange = function() {
            changeViewportContent("width=device-width, initial-scale=1.0, maximum-scale=1.0");
        },
        gestureEnd = function() {
            changeViewportContent("width=device-width, initial-scale=1.0, maximum-scale=1.0");
        };

    if (navigator.userAgent.match(/iPhone/i)) {
        initialize();

        document.addEventListener("touchstart", gestureStart, false);
        document.addEventListener("touchmove", gestureChange, false);
        document.addEventListener("touchend", gestureEnd, false);
    }
})(document);