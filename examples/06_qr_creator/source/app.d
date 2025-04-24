import std;
import guino;
import qr;

WebView wv;

void main()
{
	wv = WebView(false);

	// Import html at compile time, as string
	// You don't need to distribute the html file, it is embedded in the executable
	string html = import("main.html");

	wv.bindJs!createQRCode;
	wv.html = html;

	// Just to avoid the context menu
	wv.onInit = "window.addEventListener('contextmenu', function (e) { e.preventDefault(); });";

	// Set the size of the window
	wv.size(640, 480, WEBVIEW_HINT_FIXED);

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