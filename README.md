# guino

Add a gui to your D app using webview


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
