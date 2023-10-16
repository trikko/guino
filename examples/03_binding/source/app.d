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
						simple();
						promise(1,1).then(result => console.info('async result:' + result));
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
}

void promise(JSONValue[] v, string sequence)
{
	import core.thread;

	long a = v[0].integer;
	long b = v[1].integer;

	JSONValue sum;
	sum.integer = a+b;

	// A copy of webview visible inside the thread below
	WebView copy = wv;

	// Response will be sent after 1 second
	// from a secondary thread
	new Thread({

		// Simulate a long work
		Thread.sleep(1.seconds);

		// Let's reply
		copy.respond(
			sequence, 	// This is an identifier used to link this response to the right call
			0, 			// O means ok
			sum			// Response, encodede as json
		);

	}).start();

}
