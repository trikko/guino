import std;
import guino;
import qr;

WebView wv;

void main()
{
	wv = WebView(false);

	// Make the createQRCode function available to javascript
	wv.bindJs!createQRCode;

	// Import html at compile time, as string
	// You don't need to distribute the html file, it is embedded in the executable
	wv.html = import("main.html");

	// Just to avoid the context menu
	wv.onInit = "window.addEventListener('contextmenu', function (e) { e.preventDefault(); });";

	// Set the size of the window
	wv.size(800, 600, WEBVIEW_HINT_FIXED);

	// Run the app
	wv.run();
}

// This function is called from javascript, it generates a QR code and returns the data uri
void createQRCode(JSONValue[] args, string sequence)
{
	auto text = args[0].toString();
	auto qr = QrCode(text).toBytes();
	auto dataUri = wv.toDataUri(qr, "image/png");

	wv.resolve(sequence, JSONValue(dataUri));
}