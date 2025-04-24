# guino [docs](https://guino.dpldocs.info/guino.html)

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
    wv.size(640, 480, WEBVIEW_HINT_FIXED);
    wv.run();
  }
```

### Dependencies
Guino requires [webview](https://github.com/webview/webview) library to be present either in your executable's directory or installed in your system path. Pre-compiled binaries for Windows can be found in the [libs](https://github.com/trikko/guino/tree/main/libs) directory, while instructions for building the library from source are provided below.

### How does it works?
More examples [here](https://github.com/trikko/guino/tree/main/examples)

### Build libwebview

Checkout this repository with all submodules:
```
git clone --recurse-submodules  https://github.com/trikko/guino
```

Compile libwebview ([see also](https://github.com/webview/webview)):
```
cd guino/webview/
cmake -DWEBVIEW_BUILD=ON -DCMAKE_BUILD_TYPE=Release -DWEBVIEW_BUILD_EXAMPLES=OFF -DWEBVIEW_BUILD_DOCS=OFF -DWEBVIEW_BUILD_TESTS=OFF -DWEBVIEW_INSTALL_TARGETS=ON -DWEBVIEW_BUILD_AMALGAMATION=OFF .
cmake --build . --config Release
```

Install libwebview in your system:
```
cmake --install .
```

On linux, run `sudo ldconfig` to update the cache.
