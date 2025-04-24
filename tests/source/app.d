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


	import std.json : parseJSON, JSONValue;

	// Test case 1: Valid input
	JSONValue[] input1 = [JSONValue("hello"), JSONValue(42), JSONValue(true)];
	auto expected1 = tuple("hello", 42, true);
	assert(wv.parseJsArgs!(string, int, bool)(input1) == expected1);

	// Test case 2: Missing input
	JSONValue[] input2 = [JSONValue("world"), JSONValue(3.14)];
	auto expected2 = tuple("world", 3.14, false);
	assert(wv.parseJsArgs!(string, double, bool)(input2) == expected2);

	// Test case 3: Invalid input
	JSONValue[] input3 = [JSONValue("foo"), JSONValue("bar"), JSONValue("baz")];
	auto expected3 = tuple(int.init, bool.init, int.init);
	assert(wv.parseJsArgs!(int, bool, int)(input3) == expected3);

	// Test case 4: Named input
	JSONValue[] input4 = [JSONValue(3), JSONValue("bar"), JSONValue("baz")];
	auto ret = wv.parseJsArgs!(int, "test1", string, "str1", string, "str2")(input4);

	assert(ret.test1 == 3);
	assert(ret.str1 == "bar");
	assert(ret.str2 == "baz");

	writeln("OK, passed.");

	import core.stdc.stdlib : exit;
	exit(0);
}
