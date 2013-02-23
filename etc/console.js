function stayAtBottom (bodyFunction) {

	// work out if we are at the bottom

	var atBottom = (
		+ $(window).scrollTop ()
		+ $(window).height ()
		== $(document).height ());

	// call the function

	bodyFunction ();

	// scroll window down

	if (atBottom) {

		$(window).scrollTop (
			+ $(document).height ()
			- $(window).height ()
		);

	}

}

function deployProgress (prefix, auth, deployId, level, target, callback) {

	var connected = false;
	var completed = false;
	var connection = undefined;
	var nextSequence = 0;

	function output (html) {

		stayAtBottom (function () {
			target.append (html);
		});

	}

	function sendServer (data) {
		dataJson = JSON.stringify (data);
		connection.send (dataJson);
	}

	function connect () {

		connection =
			new WebSocket (prefix + "/deploy-progress");

		connection.onopen = function () {

			output ("<p>CONNECTED</p>");

			connected = true;

			sendServer ({
				"type": "start",
				"auth": auth,
				"deploy-id": deployId,
				"level": level,
				"sequence": nextSequence,
			});

		};

		connection.onerror = function (error) {
			output ("<p>error: " + error + "</p>");
		};

		connection.onmessage = function (message) {

			data = JSON.parse (message.data);

			if (data["sequence"] < nextSequence) {
				output ("<p>DATA SEQUENCE ERROR</p>");
				return;
			}

			nextSequence = data["sequence"] + 1;

			switch (data.type) {

			case "deploy-start":
				output ("<p>DEPLOY START</p>");
				break;

			case "deploy-log":
				output (data.html);
				break;

			case "deploy-end":
				output ("<p>DEPLOY END</p>");
				completed = true;
				connection.close ();
				callback ();
				break;

			default:
				output ("<p>Invalid data type: " + data.type + "</p>");
			}

		};

		connection.onclose = function (message) {

			if (connected) {
				output ("<p>CONNECTION LOST</p>\n");
				connected = false;
			}

			if (! completed)
				setTimeout (connect, 1000);

		};

	};

	connect ();

}

$(function () {

	var header = $("header");
	var main = $("div.main");

	var headerHeight = header.height ();

	header.css ("position", "fixed");
	header.css ("top", "0");
	header.css ("left", "0");
	header.css ("right", "0");

	main.css ("margin-top", headerHeight);

});
