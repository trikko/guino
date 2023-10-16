import guino;
WebView wv;

void main()
{
	wv = WebView(true);
	wv.html = `
	<html><body>
			<button onclick="test()">click me!</button>
			<a id="mylink">hello</a>
	</body></html>
	`;

	wv.bindJs!test;
	wv.size(600, 400);
	wv.run();
}

void test()
{
	// innerText, setAttribute and everything else are forwarded to js as is.
	wv.byId("mylink").innerText = "changed!";
	wv.byId("mylink").setAttribute("href", "https://example.com");
}