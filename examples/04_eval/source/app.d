import guino;
import std;

WebView wv = WebView.init;

void main()
{
	string html = `
	<html>
		<body>

			<button id="clickme" onclick="action()">test</button>

			<div id="greetings"></div>

		</body>
	</html>`;

	wv = WebView(true);
	wv.bindJs!action;
	wv.html = html;
	wv.size(640, 480, WEBVIEW_HINT_FIXED);
	wv.run();

}

void action()
{
	// Run some js code
	wv.eval("document.getElementById('greetings').innerText = 'hello'");

	// Return the result when ready
	wv.eval!callme("1+2");

	// Limited direct access to element
	wv.byId("clickme").innerText = "CLICKED";
}

void callme(JSONValue v)
{
	writeln("RESULT: ", v.integer);
}