# guino [![Build status](https://ci.appveyor.com/api/projects/status/vi5t1sv69iopb88d?svg=true)](https://ci.appveyor.com/project/trikko/guino) [docs](https://guino.dpldocs.info/guino.html)

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

### How does it works?
More examples [here](https://github.com/trikko/guino/tree/main/examples)

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

On linux, run `sudo ldconfig` to update the cache.

### Extra steps on macOS:

Make sure that the path `/usr/local/lib` is included in the `DYLD_LIBRARY_PATH` environment variable. For example, you can run your project with:

```bash
DYLD_LIBRARY_PATH=/usr/local/lib dub
```

Alternatively, you can add the following line to your `bashrc`:

```bash
export DYLD_LIBRARY_PATH=/usr/local/lib
```

and run it with `dub`

### Build libwebview on windows

Libraries for windows are shipped inside the repository but you can build from source:

```
git clone --recurse-submodules  https://github.com/trikko/guino
```

Compile libwebview ([see also](https://github.com/webview/webview)):
```
guino/webview/script/build.bat build
```
