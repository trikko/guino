module guino;

import std.json;
import std.string;
import std.conv : to;

// Window size hints
enum WEBVIEW_HINT_NONE  =  0;    /// Width and height are default size
enum WEBVIEW_HINT_MIN   =  1;    /// Width and height are minimum bounds
enum WEBVIEW_HINT_MAX   =  2;    /// Width and height are maximum bounds
enum WEBVIEW_HINT_FIXED =  3;    /// Window size can not be changed by a user

/// The main struct
struct WebView {

   private webview_t handle = null;

   /++ Create a new WebView.
   + Params: enableDebug = allow code inspection from webview
   +/
   this(bool enableDebug, void * window = null) { create(enableDebug, window); }

   /// Ditto
   void create(bool enableDebug = false, void * window = null) in(handle is null, error_already_inited)
   {
      handle = webview_create(enableDebug, window);
      assert(handle !is null, "Webview library loaded, but failed to create window. Any missing webview dependencies?");
   }

   /// Start the WebView. Be sure to set size before.
   void run() in(handle !is null, error_not_inited) { webview_run(handle); }

   /++ Set webview HTML directly.
   + ---
      webview.html = "<html><body>hello, world!</body></html>";
   + ---
   +/
   void html(string data) in(handle !is null, error_not_inited) { webview_set_html(handle, data.toStringz); }

   /// Navigates webview to the given URL. URL may be a properly encoded data URI.
   void navigate(string url) in(handle !is null, error_not_inited) { webview_navigate(handle, url.toStringz); }

   /// Set the window title
   void title(string title) in(handle !is null, error_not_inited) { webview_set_title(handle, title.toStringz);}

   /// Set the window size
   void size(int width, int height, int hints = WEBVIEW_HINT_NONE) in(handle !is null, error_not_inited) { webview_set_size(handle, width, height, hints);}

   ///
   void terminate() { if(handle !is null) webview_terminate(handle); handle = null; }

   /// Returns a handle to the native window
   void* window() in(handle !is null, error_not_inited) { return webview_get_window(handle); }


   /++ Eval some js code. When it is done, `func()` is called (optional)
    + ---
    + void callback(JSValue v) { writeln("Result from js: ", v); }
    + webview.eval!callback("1+1");
    + ---
    +/
   void eval(alias func = null)(string js, void* extra = null)
   in(handle !is null, error_not_inited)
   {
      static if (is (typeof(func) == typeof(null))) webview_eval(handle, js.toStringz);
      else
      {
         import std.uuid;

         struct EvalPayload
         {
            void        *extra;
            webview_t   handle;
            string      uuid;
         }

         auto uuid = "__eval__" ~ randomUUID().toString.replace("-", "_");
         EvalPayload *payload = new EvalPayload(extra, handle, uuid);

         bindJs!(
            (JSONValue[] v, void* extra)
            {
               import core.memory : GC;

               EvalPayload *p = cast(EvalPayload*) extra;
               webview_unbind(p.handle, p.uuid.toStringz);
               static if (__traits(compiles, func(v[0], p.extra))) func(v[0], p.extra);
               else func(v[0]);
               p.destroy();
               GC.free(p);
            }
         )
         (uuid, cast(void*)payload);

         eval(uuid ~ `(eval('` ~ js.escapeJs() ~ `'));`);
      }
   }

   /++ Helper function to convert a file to data uri to embed inside html.
   + It works at compile-time so you must set source import paths on your project.
   + See_Also: [toDataUri], [fileAsDataUri], https://dlang.org/spec/expression.html#import_expressions
   + ---
   + webview.byId("myimg").src = importAsDataUri!"image.jpg";
   +/
   static string importAsDataUri(string file)(string mimeType = "application/octet-stream")
   {
      import std.algorithm;
      import std.encoding;
      import std.base64;

      auto mime = mimeType;
      auto extIdx = file.lastIndexOf('.');
      if (extIdx >= 0 && file[extIdx..$] in mimeTypes)
         mime = mimeTypes[file[extIdx..$]];

      auto bytes = import(file).representation;
      auto bom = getBOM(bytes);
      bytes = bytes[bom.sequence.length .. $];

      return WebView.toDataUri(bytes, mime);
   }

   /++ Helper function to convert bytes to data uri to embed inside html
   + See_Also: [importAsDataUri], [fileAsDataUri]
   +/
   static auto toDataUri(const ubyte[] bytes, string mimeType = "application/octet-stream")
   {
      import std.base64;
      return ("data:" ~ mimeType ~ ";base64," ~ Base64.encode(bytes));
   }

   /++ Helper function to convert bytes to data uri to embed inside html
   + See_Also: [importAsDataUri], [toDataUri]
   +/
   static string fileAsDataUri(string file, string mimeType = "application/octet-stream")
   {
      import std.file;
      auto mime = mimeType;
      auto extIdx = file.lastIndexOf('.');
      if (extIdx >= 0 && file[extIdx..$] in mimeTypes)
         mime = mimeTypes[file[extIdx..$]];

      ubyte[] data = cast(ubyte[])std.file.read(file);
      return toDataUri(data, mime);
   }

   /++ Injects JavaScript code at the initialization of the new page. Every time
     + the webview will open a new page - this initialization code will be
     + executed. It is guaranteed that code is executed before window.onload.
     +/
   void onInit(string js) in(handle !is null, error_not_inited) { webview_init(handle, js.toStringz); }

   /// Ditto
   void onInit(alias func)()
   {
      import std.uuid;
      string uuid = "_init_" ~ randomUUID.toString().replace("-", "_");
      static void proxy(JSONValue[]) { func(); }
      bindJs!(proxy)(uuid);
      onInit(uuid ~ "();");
   }


   /++ Respond to a binding call from js.
   + See_Also: [resolve], [reject]
   +/
   void respond(string seq, bool resolved, JSONValue v) in(handle !is null, error_not_inited) { webview_return(handle, seq.toStringz, resolved?0:1, v.toString.toStringz); }

   /++ Resolve a js promise
   + See_Also: [respond], [reject]
   +/
   void resolve(string seq, JSONValue v) in(handle !is null, error_not_inited) { respond(seq, true, v); }

   /++ Reject a js promise
   + See_Also: [respond], [resolve]
   +/
   void reject(string seq, JSONValue v) in(handle !is null, error_not_inited) { respond(seq, false, v); }

   /++ Removes a D callback that was previously set by `bind()`
    +  See_Also: [bindJs]
    ++/
   void unbindJs(string name) in(handle !is null, error_not_inited) { webview_unbind(handle, name.toStringz); }

   /++ Create a callback in D for a js function.
     + See_Also: [response], [resolve], [reject], [unbindJs]
     + ---
     + // Simple callback without params
     + void hello() { ... }
     +
     + // Js arguments will be passed as JSON array
     + void world(JSONValue[] args) { ... }
     +
     + // You can use the sequence arg to return a response.
     + void reply(JSONValue[] args, string sequence) { ... resolve(sequence, JSONValue("Hello Js!")); }
     +
     + webview.bind!hello;          // If you call hello() from js, hello() from D will respond
     + webview.bind!hello("test")   // If tou call test() from js, hello() from D will respond
     + ---
     +/
   void bindJs(alias func)(string jsFunc = __traits(identifier, func), void* extra = null)
   in(handle !is null, error_not_inited)
   {

      static if (__traits(compiles, func(JSONValue[].init, string.init, (void *).init)))
         extern(C) void callback(const char *seq, const char *request, void *extra)
         {
            func(parseJSON(request.to!string).array, seq.to!string, extra);
         }

      else static if (__traits(compiles, func(JSONValue[].init, (void*).init)))
         extern(C) void callback(const char *seq, const char *request, void *extra)
         {
            func(parseJSON(request.to!string).array, extra);
         }


      else static if (__traits(compiles, func(JSONValue[].init, string.init)))
         extern(C) void callback(const char *seq, const char *request, void *extra)
         {
            func(parseJSON(request.to!string).array, seq.to!string);
         }

      else static if (__traits(compiles, func(JSONValue[].init)))
         extern(C) void callback(const char *seq, const char *request, void *extra)
         {
            func(parseJSON(request.to!string).array);
         }

      else static if (__traits(compiles, func()))
         extern(C) void callback(const char *seq, const char *request, void *extra)
         {
            func();
         }


      static if (__traits(compiles, callback(null, null, null))) webview_bind(handle, jsFunc.toStringz, &callback, extra);
      else static assert(0, "Can't bind `" ~ typeof(func).stringof ~ "` try with `void func(JSONValue[] args)`, for example.");
   }

   /// Ditto
   void bindJs(alias func)(void* extra) in(handle !is null, error_not_inited) { bindJs!func( __traits(identifier, func), extra); }


   /++ A helper function to parse args passed as JSONValue[]
    + See_Also: [bindJs]
    + ---
    + void myFunction(JSONValue[] arg)
    + {
    +    with(WebView.parseJsArgs!(int, "hello", string, "world")(args))
    +    {
    +       // Just like we have named args
    +       writeln(hello);
    +       writeln(world);
    +    }
    + }
    + ---
    +/
   static auto parseJsArgs(T...)(JSONValue[] v)
   {
      import std.typecons : Tuple;

      alias TUPLE = Tuple!T;
      TUPLE ret;

      foreach (i, ref arg; ret)
      {
         if (i < v.length)
         {
               try { arg = v[i].get!(typeof(arg)); }
               catch (Exception e) { arg = typeof(arg).init;}
         }
         else arg = typeof(arg).init;
      }

      return ret;
   }


   /++ Search for an element in the dom, using a css selector. Returned element can forward calls to js.
   + See_Also: [byId]
   +/
   Element bySelector(string query)
   in(handle !is null, error_not_inited)
   {
      return new Element(this, "document.querySelector('" ~ query.escapeJs() ~ "')");
   }

   /++  Search for an element in the dom, using id. Returned element can forward calls to js.
   + See_Also: [bySelector]
   + ---
   + webview.byId("myid").innerText = "Hi!";
   + webview.byId("myid").setAttribute("href", "https://example.com");
   + ---
   +/
   Element byId(string id)
   in(handle !is null, error_not_inited)
   {
      return new Element(this, "document.getElementById('" ~ id.escapeJs() ~ "')");
   }

   class Element
   {
      private string js;
      private WebView wv;

      private this(WebView wv, string js) { this.wv = wv; this.js = js; }


      // Try to use js dom from D
      void opDispatch(string name, T...)(T val) {

         static if (T.length == 0) zeroParamsOpDispatch!(name)(val);
         else static if (T.length == 1) singleParamOpDispatch!(name)(val);
         else static if (T.length > 1)
         {

            import std.conv;
            import std.traits;
            import std.string;

            string jsCode = js ~ "." ~ name ~ "(";

            static foreach(v; val)
            {
               static if (isIntegral!(typeof(v)) || isFloatingPoint!(typeof(v))) jsCode ~= v.to!string ~ ",";
               else static if (isSomeString!(typeof(v))) jsCode ~= `'` ~ v.escapeJs() ~ `',`;
               else throw new Exception("Can't assign " ~ T.stringof);
            }

            if (jsCode.endsWith(",")) jsCode = jsCode[0..$-1];

            jsCode ~= ")";
            wv.eval(jsCode);
         }

      }

      private void zeroParamOpDispatch(string name, T)(T val) {
         import std.conv;
         import std.traits;

         string jsCode;

         string fullName = js ~ "." ~ name;

         jsCode ~= "if (" ~fullName ~ " != null && (" ~ fullName ~ " instanceof Function)) {\n";
         jsCode ~= fullName ~ "()";
         jsCode ~= "\n}";

         wv.eval(jsCode);
      }

      private void singleParamOpDispatch(string name, T)(T val) {
         import std.conv;
         import std.traits;

         string jsCode;

         string fullName = js ~ "." ~ name;

         jsCode ~= "if (" ~fullName ~ " != null && (" ~ fullName ~ " instanceof Function)) {\n";
         jsCode ~= js ~ "." ~ name;
         static if (isIntegral!T || isFloatingPoint!T) jsCode ~= val.to!string;
         else static if (isSomeString!T) jsCode ~= `('` ~ val.escapeJs() ~ "'";
         else throw new Exception("Can't assign " ~ T.stringof);
         jsCode ~= ");";

         jsCode ~= "\n} else { \n";
         static if (isIntegral!T || isFloatingPoint!T) jsCode ~= js ~ "." ~ name ~ `=` ~ val.to!string ~ ";";
         else static if (isSomeString!T) jsCode ~= js ~ "." ~ name ~ `= '` ~ val.escapeJs() ~ "';";
         else throw new Exception("Can't assign " ~ T.stringof);

         jsCode ~= "\n}";

         wv.eval(jsCode);
      }

      void setAttribute(T)(string name, T val) {
         import std.conv;
         import std.traits;

         string jsCode;

         static if (isIntegral!T || isFloatingPoint!T) jsCode = js ~ ".setAttribute('" ~ name.escapeJs() ~ `', ` ~ val.to!string ~ ");";
         else static if (isSomeString!T) jsCode = js ~ ".setAttribute('" ~ name.escapeJs() ~ `', '` ~ val.escapeJs() ~ "');";
         else throw new Exception("Can't assign " ~ T.stringof);

         wv.eval(jsCode);
      }

   }

   class Elements
   {
      private string js;
      private WebView wv;

      private this(WebView wv, string js) { this.wv = wv; this.js = js; }

      Element opIndex(size_t idx)
      {
         return new Element(wv, js ~ "[" ~ idx.to!string ~ "]");
      }

   }

}

/// Helper function to escape js strings
string escapeJs(string s, char stringDelimeter = '\'')
{
   import std.utf;

   string result;

   foreach(ref c; s.byCodeUnit)
   {
      if (c == '\\') result ~= `\\`;
      else if (c == '"') result ~= `\"`;
      else if (c == '\'') result ~= `\'`;
      else if (c == '\t') result ~= `\t`;
      else if (c == '\n') result ~= `\n`;
      else if (c == '\r') result ~= `\r`;
      else if (c == '\u000B') result ~= `\v`;
      else if (c == '\u000C') result ~= `\f`;
      else if (c < 32 || c == 127) result ~= `\u` ~ format("%04x", c);
      else result ~= c;
   }

   return result;
}


private:

private immutable error_not_inited = "WebView is not initialized. Please call .create() method first.";
private immutable error_already_inited = "Please call .terminate() first.";

enum string[string] mimeTypes =
[
   // Text/document formats
   ".html" : "text/html", ".htm" : "text/html", ".shtml" : "text/html", ".css" : "text/css", ".xml" : "text/xml",
   ".txt" : "text/plain", ".md" : "text/markdown", ".csv" : "text/csv", ".yaml" : "text/yaml", ".yml" : "text/yaml",
   ".jad" : "text/vnd.sun.j2me.app-descriptor", ".wml" : "text/vnd.wap.wml", ".htc" : "text/x-component",

   // Image formats
   ".gif" : "image/gif", ".jpeg" : "image/jpeg", ".jpg" : "image/jpeg", ".png" : "image/png",
   ".tif" : "image/tiff", ".tiff" : "image/tiff", ".wbmp" : "image/vnd.wap.wbmp",
   ".ico" : "image/x-icon", ".jng" : "image/x-jng", ".bmp" : "image/x-ms-bmp",
   ".svg" : "image/svg+xml", ".svgz" : "image/svg+xml", ".webp" : "image/webp",
   ".avif" : "image/avif", ".heic" : "image/heic", ".heif" : "image/heif", ".jxl" : "image/jxl",

   // Web fonts
   ".woff" : "application/font-woff", ".woff2": "font/woff2", ".ttf" : "font/ttf", ".otf" : "font/otf",
   ".eot" : "application/vnd.ms-fontobject",

   // Archives and applications
   ".jar" : "application/java-archive", ".war" : "application/java-archive", ".ear" : "application/java-archive",
   ".json" : "application/json", ".hqx" : "application/mac-binhex40", ".doc" : "application/msword",
   ".pdf" : "application/pdf", ".ps" : "application/postscript", ".eps" : "application/postscript",
   ".ai" : "application/postscript", ".rtf" : "application/rtf", ".m3u8" : "application/vnd.apple.mpegurl",
   ".xls" : "application/vnd.ms-excel", ".ppt" : "application/vnd.ms-powerpoint", ".wmlc" : "application/vnd.wap.wmlc",
   ".kml" : "application/vnd.google-earth.kml+xml", ".kmz" : "application/vnd.google-earth.kmz",
   ".7z" : "application/x-7z-compressed", ".cco" : "application/x-cocoa",
   ".jardiff" : "application/x-java-archive-diff", ".jnlp" : "application/x-java-jnlp-file",
   ".run" : "application/x-makeself", ".pl" : "application/x-perl", ".pm" : "application/x-perl",
   ".prc" : "application/x-pilot", ".pdb" : "application/x-pilot", ".rar" : "application/x-rar-compressed",
   ".rpm" : "application/x-redhat-package-manager", ".sea" : "application/x-sea",
   ".swf" : "application/x-shockwave-flash", ".sit" : "application/x-stuffit", ".tcl" : "application/x-tcl",
   ".tk" : "application/x-tcl", ".der" : "application/x-x509-ca-cert", ".pem" : "application/x-x509-ca-cert",
   ".crt" : "application/x-x509-ca-cert", ".xpi" : "application/x-xpinstall", ".xhtml" : "application/xhtml+xml",
   ".xspf" : "application/xspf+xml", ".zip" : "application/zip",
   ".br" : "application/x-brotli", ".gz" : "application/gzip",
   ".bz2" : "application/x-bzip2", ".xz" : "application/x-xz",

   // Generic binary files
   ".bin" : "application/octet-stream", ".exe" : "application/octet-stream", ".dll" : "application/octet-stream",
   ".deb" : "application/octet-stream", ".dmg" : "application/octet-stream", ".iso" : "application/octet-stream",
   ".img" : "application/octet-stream", ".msi" : "application/octet-stream", ".msp" : "application/octet-stream",
   ".msm" : "application/octet-stream",

   // Office documents
   ".docx" : "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
   ".xlsx" : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
   ".pptx" : "application/vnd.openxmlformats-officedocument.presentationml.presentation",

   // Audio formats
   ".mid" : "audio/midi", ".midi" : "audio/midi", ".kar" : "audio/midi",
   ".mp3" : "audio/mpeg", ".ogg" : "audio/ogg", ".m4a" : "audio/x-m4a",
   ".ra" : "audio/x-realaudio", ".opus" : "audio/opus", ".aac" : "audio/aac",
   ".flac" : "audio/flac",

   // Video
   ".3gpp" : "video/3gpp", ".3gp" : "video/3gpp", ".ts" : "video/mp2t", ".mp4" : "video/mp4",
   ".mpeg" : "video/mpeg", ".mpg" : "video/mpeg", ".mov" : "video/quicktime",
   ".webm" : "video/webm", ".flv" : "video/x-flv", ".m4v" : "video/x-m4v",
   ".mng" : "video/x-mng", ".asx" : "video/x-ms-asf", ".asf" : "video/x-ms-asf",
   ".wmv" : "video/x-ms-wmv", ".avi" : "video/x-msvideo",
   ".mkv" : "video/x-matroska", ".ogv" : "video/ogg",

   // Web development
   ".js" : "application/javascript", ".wasm" : "application/wasm",
   ".ts" : "application/typescript",
   ".atom" : "application/atom+xml", ".rss" : "application/rss+xml",
   ".mml" : "text/mathml"
];


alias webview_t = void*;
alias dispatchCallback = extern(C) void function(webview_t w, void* arg);
alias bindCallback = extern(C) void function(const char *seq, const char *req, void *arg);

private:
version(dynamic_loading) {

   __gshared LibHandle libHandle;
   __gshared bool symbolsLoaded = false;

   // Define the type for the dynamic library
   version(Windows) {
      import core.sys.windows.windows;
      alias LibHandle = HMODULE;
   } else version(Posix) {
      alias LibHandle = void*;
   }

   // Functions to load the library
   version(Windows) {
      import core.sys.windows.windows;
      import core.sys.windows.dll;

      bool loadLibrary(string libName) {
         libHandle = LoadLibraryA(libName.toStringz);
         return libHandle !is null;
      }

      void* getSymbol(string name) {
         return GetProcAddress(libHandle, name.toStringz);
      }

      void unloadLibrary() {
         if(libHandle !is null) {
               FreeLibrary(libHandle);
               libHandle = null;
         }
      }
   } else version(Posix) {
      import core.sys.posix.dlfcn;

      bool loadLibrary(string libName) {
         libHandle = dlopen(libName.toStringz, RTLD_LAZY);
         return libHandle !is null;
      }

      void* getSymbol(string name) {
         return dlsym(libHandle, name.toStringz);
      }

      void unloadLibrary() {
         if(libHandle !is null) {
               dlclose(libHandle);
               libHandle = null;
         }
      }
   }

   __gshared {
      extern(C) webview_t function(int _debug, void *window) webview_create;
      extern(C) void function(webview_t w) webview_destroy;
      extern(C) void function(webview_t w) webview_run;
      extern(C) void function(webview_t w) webview_terminate;
      extern(C) void function(webview_t w, dispatchCallback, void *arg) webview_dispatch;
      extern(C) void* function(webview_t w) webview_get_window;
      extern(C) void function(webview_t w, const char *title) webview_set_title;
      extern(C) void function(webview_t w, int width, int height, int hints) webview_set_size;
      extern(C) void function(webview_t w, const char *url) webview_navigate;
      extern(C) void function(webview_t w, const char *html) webview_set_html;
      extern(C) void function(webview_t w, const char *js) webview_init;
      extern(C) void function(webview_t w, const char *js) webview_eval;
      extern(C) void function(webview_t w, const char *name, bindCallback, void *arg) webview_bind;
      extern(C) void function(webview_t w, const char *name) webview_unbind;
      extern(C) void function(webview_t w, const char *seq, int status, const char *result) webview_return;
   }


   // Loads the symbols from the library
   bool loadSymbols() {
      if (symbolsLoaded) return true;

      import std.path : buildNormalizedPath, dirName;
      import std.file : getcwd, thisExePath;
      import std.array : join;

      string[] candidates;

      version(Windows) candidates = [buildNormalizedPath(thisExePath.dirName, "webview.dll"), "webview.dll"];
      else version(OSX) candidates = [buildNormalizedPath(thisExePath.dirName, "libwebview.dylib"), buildNormalizedPath(thisExePath.dirName, "..", "Frameworks", "libwebview.dylib"), "/System/Library/Frameworks/libwebview.dylib", "/opt/homebrew/lib/libwebview.dylib", "/usr/local/lib/libwebview.dylib", "/usr/lib/libwebview.dylib", "libwebview.dylib"];
      else version(linux) candidates = [buildNormalizedPath(thisExePath.dirName, "libwebview.so"), "libwebview.so", "/usr/local/lib/libwebview.so", "/usr/lib/libwebview.so"];
      else throw new Exception("Unsupported platform");

      bool inited = false;
      foreach (candidate; candidates) {

         if (loadLibrary(candidate)) {
            inited = true;
            break;
         }
      }

      if (!inited) {
         throw new Exception("Failed to load webview library/symbols. Tried: " ~ candidates.join(", "));
      }

      webview_create = cast(typeof(webview_create))getSymbol("webview_create");
      webview_destroy = cast(typeof(webview_destroy))getSymbol("webview_destroy");
      webview_run = cast(typeof(webview_run))getSymbol("webview_run");
      webview_terminate = cast(typeof(webview_terminate))getSymbol("webview_terminate");
      webview_dispatch = cast(typeof(webview_dispatch))getSymbol("webview_dispatch");
      webview_get_window = cast(typeof(webview_get_window))getSymbol("webview_get_window");
      webview_set_title = cast(typeof(webview_set_title))getSymbol("webview_set_title");
      webview_set_size = cast(typeof(webview_set_size))getSymbol("webview_set_size");
      webview_navigate = cast(typeof(webview_navigate))getSymbol("webview_navigate");
      webview_set_html = cast(typeof(webview_set_html))getSymbol("webview_set_html");
      webview_init = cast(typeof(webview_init))getSymbol("webview_init");
      webview_eval = cast(typeof(webview_eval))getSymbol("webview_eval");
      webview_bind = cast(typeof(webview_bind))getSymbol("webview_bind");
      webview_unbind = cast(typeof(webview_unbind))getSymbol("webview_unbind");
      webview_return = cast(typeof(webview_return))getSymbol("webview_return");


      // Is everything loaded?
      if (webview_create is null || webview_destroy is null || webview_run is null ||
         webview_terminate is null || webview_dispatch is null || webview_get_window is null ||
         webview_set_title is null || webview_set_size is null || webview_navigate is null ||
         webview_set_html is null || webview_init is null || webview_eval is null ||
         webview_bind is null || webview_unbind is null || webview_return is null) {
         unloadLibrary();
         return false;
      }

      symbolsLoaded = true;
      return true;
   }

   shared static this() { loadSymbols(); }
   shared static ~this() { unloadLibrary(); }
}

else version(static_loading) {

   // Creates a new webview instance. If debug is non-zero - developer tools will
   // be enabled (if the platform supports them). The window parameter can be a
   // pointer to the native window wb.handle. If it's non-null - then child WebView
   // is embedded into the given parent window. Otherwise a new window is created.
   // Depending on the platform, a GtkWindow, NSWindow or HWND pointer can be
   // passed here. Returns null on failure. Creation can fail for various reasons
   // such as when required runtime dependencies are missing or when window creation
   // fails.
   extern(C) webview_t webview_create(int _debug, void *window);

   // Destroys a webview and closes the native window.
   extern(C)  void webview_destroy(webview_t w);

   // Runs the main loop until it's terminated. After this function exits - you
   // must destroy the webview.
   extern(C)  void webview_run(webview_t w);

   // Stops the main loop. It is safe to call this function from another other
   // background thread.
   extern(C)  void webview_terminate(webview_t w);

   // Posts a function to be executed on the main thread. You normally do not need
   // to call this function, unless you want to tweak the native window.
   extern(C)  void
   webview_dispatch(webview_t w, dispatchCallback, void *arg);


   // Returns a native window wb.handle pointer. When using a GTK backend the pointer
   // is a GtkWindow pointer, when using a Cocoa backend the pointer is a NSWindow
   // pointer, when using a Win32 backend the pointer is a HWND pointer.
   extern(C)  void *webview_get_window(webview_t w);

   // Updates the title of the native window. Must be called from the UI thread.
   extern(C)  void webview_set_title(webview_t w, const char *title);


   // Updates the size of the native window. See WEBVIEW_HINT constants.
   extern(C)  void webview_set_size(webview_t w, int width, int height,
                                    int hints);

   // Navigates webview to the given URL. URL may be a properly encoded data URI.
   // Examples:
   // webview_navigate(w, "https://github.com/webview/webview");
   // webview_navigate(w, "data:text/html,%3Ch1%3EHello%3C%2Fh1%3E");
   // webview_navigate(w, "data:text/html;base64,PGgxPkhlbGxvPC9oMT4=");
   extern(C)  void webview_navigate(webview_t w, const char *url);

   // Set webview HTML directly.
   // Example: webview_set_html(w, "<h1>Hello</h1>");
   extern(C)  void webview_set_html(webview_t w, const char *html);

   // Injects JavaScript code at the initialization of the new page. Every time
   // the webview will open a new page this initialization code will be
   // executed. It is guaranteed that code is executed before window.onload.
   extern(C)  void webview_init(webview_t w, const char *js);

   // Evaluates arbitrary JavaScript code. Evaluation happens asynchronously, also
   // the result of the expression is ignored. Use RPC bindings if you want to
   // receive notifications about the results of the evaluation.
   extern(C)  void webview_eval(webview_t w, const char *js);

   // Binds a native C callback so that it will appear under the given name as a
   // global JavaScript function. Internally it uses webview_init(). The callback
   // receives a sequential request id, a request string and a user-provided
   // argument pointer. The request string is a JSON array of all the arguments
   // passed to the JavaScript function.
   extern(C)  void webview_bind(webview_t w, const char *name,
                                 bindCallback,
                                 void *arg);

   // Removes a native C callback that was previously set by webview_bind.
   extern(C)  void webview_unbind(webview_t w, const char *name);

   // Responds to a binding call from the JS side. The ID/sequence number must
   // match the value passed to the binding wb.handler in order to respond to the
   // call and complete the promise on the JS side. A status of zero resolves
   // the promise, and any other value rejects it. The result must either be a
   // valid JSON value or an empty string for the primitive JS value "undefined".
   extern(C)  void webview_return(webview_t w, const char *seq, int status, const char *result);
}

else static assert(false, "Unsupported configuration. Please use either dynamic_loading or static_loading.");
