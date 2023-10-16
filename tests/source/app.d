module tests.app;

import std;
import guino;

__gshared WebView wv = WebView.init;
bool works = true;

void main()
{
	wv = WebView(true);

	// Self-contained
	auto html = import("ui.html").replace("test.js", WebView.importAsDataUri!"test.js");

	wv.html = html;
	wv.title = "Testing";
	wv.bindJs!d_function;
	wv.bindJs!d_promise_renamed("d_promise");

	wv.run();

}

void d_function(JSONValue[] v) {

	assert(v[0].str == "one");
	assert(v[1].integer == 2);

	auto args = WebView.parseJsArgs!(string, "first", int, "second", string, "third")(v);

	assert(args.first == "one");
	assert(args.second == 2);
	assert(args.third == "three");

	wv.eval!eval_callback("document.getElementById('element').innerText");
	wv.eval("js_function('test from d')");
}


void eval_callback(JSONValue v)
{
	assert(v.str == "something");
	wv.byId("dynamic").innerText = "testing opDispatch";

	import core.thread;
	new Thread({
		Thread.sleep(200.msecs);

		wv.eval!check_all("document.documentElement.innerHTML");
	}).start();
}

void d_promise_renamed(JSONValue[] v, string sequence)
{
	with(WebView.parseJsArgs!(int, "first", int, "second")(v))
	{
		assert(v[0].integer == 1);
		assert(v[1].integer == 2);

		//with(args)
		{
			assert(first == 1);
			assert(second == 2);

			wv.resolve(sequence, JSONValue(first+second));
		}
	}
}

void check_all(JSONValue v)
{
	string data = v.str;
	assert(data.canFind(`<div id="dynamic">testing opDispatch</div>`));
	assert(data.canFind(`<div id="element">something</div>`));
	assert(data.canFind(`<div id="result">3</div>`));
	assert(data.canFind(`<div id="from_js">test from d</div>`));

	wv.terminate();
}