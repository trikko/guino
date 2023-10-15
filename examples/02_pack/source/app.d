import guino;
import std.string;

// This executable is self-contained.
// All data (html, picture) are saved as resource.

// File is imported at compile-time as string from "assets" dir
// Nothing will be read from that directory when app runs
// It is encoded as data uri (base64)
immutable picture = WebView.importAsDataUri!"background.jpg";

void main()
{
	WebView wv = WebView(true);

	// Import html at compile time, as string
	string html = import("main.html");

	// Replace "background.jpg" link with actual bytes
	// encoded as base64 data
	html = html.replace("background.jpg", picture);

	wv.html = html;

	wv.size(640, 480, WEBVIEW_HINT_FIXED);
	wv.run();
}
