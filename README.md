# guino

Unleash guino magic for effortless GUI development in D!

### Hello, world!

Add guino to your dub project:
```
dub add guino
```

Minimal example:

```d
  import guino;
  void main()
  {
    WebView wv = WebView(true);
    wv.html = "<html><body>hello world</body></html>";
    wv.run();
  }
```

### Call D function from JS and viceversa

```d
import std;
import guino;

WebView wv = WebView.init;

void main() {

  // Create a webview
  wv = WebView(true);

  // HTML to display
  auto html = `
    <html><body>
      <button id="btn" onclick="hello('world')">CLICK ME!</button>
      <script>
        function change(s) {
          document.getElementById('btn').innerText = s;
        }
      </script>
    </body></html>`;
  
  wv.html = html;   // Show html
  wv.bindJs!hello;  // Now you can call D function `hello` from js
  wv.run();

}


void hello(JSONValue[] v) {
  writeln("RECEIVED: ", v[0].str, " from javascript!");
  writeln("Let's call a js function");

  // Execute some js code on the client
  wv.eval("change('CLICKED')");
}
```

### Build libwebview on linux/macOS

Checkout this repository with all submodules:
```
git clone --recurse-submodules  https://github.com/trikko/guino
```

Compile libwebview ([see also](https://github.com/webview/webview)):
```
guino/webview/script/build.sh build
```

Install libwebview in your system:
```
sudo cp guino/webview/build/library/libwebview.* /usr/local/lib/
```
