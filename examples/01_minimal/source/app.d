import guino;

void main()
{
   WebView wv = WebView(true);
   wv.html = "<html><body>hello world</body></html>";
   wv.run();
}
