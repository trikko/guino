import std;
import guino;

WebView wv = WebView.init;

void main()
{
	string html = `
		<html>
			<head>
				<script>
					onload = (event) => {

						promise(1,1).then(
							result => console.info('Promise WORKED: ' + result),
							error => console.info('Promise FAILED: ' + error)
						);

						simple();
						renamed('a', 3);
					}
				</script>
			</head>
			<body>
			</body>
		</html>
	`;

	wv = WebView(true);
	wv.html = html;
	wv.bindJs!simple;
	wv.bindJs!alternate("renamed");
	wv.bindJs!promise;
	wv.size(640, 480, WEBVIEW_HINT_FIXED);
	wv.run();
}


void simple()
{
	writeln("simple() called from js");
}

void alternate(JSONValue[] values)
{
	writeln("renamed() called from js");

	writeln();

	// Args can be read from json
	foreach(size_t k, v; values)
		writeln("args #", k, " => ", v);

	// Or you can convert JSONValue[] into a tuple
	// In this case we create a tuple with two fields (string first, int number)
	auto args = WebView.parseJsArgs!(string, "first", int, "number")(values);

	// So you can use like this
	writeln("args: ", args.first, ", ", args.number);

	// Using dlang "with" to add syntax sugar
	with(WebView.parseJsArgs!(string, "param", int, "number")(values))
	{
		writeln("args: ", param, ", ", number);
	}


}

void promise(JSONValue[] v, string sequence)
{
	import core.thread;

	long a = v[0].integer;
	long b = v[1].integer;

	string result = "The sum of %s+%s is %s".format(a, b, a+b);

	// A copy of webview visible inside the thread below
	WebView copy = wv;

	// Response will be sent after 1 second
	// from a secondary thread
	new Thread({

		// Simulate a long work
		Thread.sleep(1.seconds);

		// Let's give a positive feedback :)
		copy.resolve(sequence, JSONValue(result));

		// Replace the line above with this one!
		// copy.reject(sequence, JSONValue("oh no!"));

	}).start();

}
