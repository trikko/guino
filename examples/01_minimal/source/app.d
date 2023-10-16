import guino;

void main()
{
   WebView wv = WebView(true);
   wv.html = "<html><body>hello world</body></html>";
   wv.size(640, 480, WEBVIEW_HINT_FIXED);
   wv.run();
}
