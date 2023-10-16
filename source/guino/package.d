module guino;

import std.json;
import std.string;
import std.conv : to;

// Window size hints
enum WEBVIEW_HINT_NONE=0;  // Width and height are default size
enum WEBVIEW_HINT_MIN=1;   // Width and height are minimum bounds
enum WEBVIEW_HINT_MAX=2;   // Width and height are maximum bounds
enum WEBVIEW_HINT_FIXED=3; // Window size can not be changed by a user


struct WebView {

   private webview_t handle = null;

   @disable this();

   this(bool enableDebug, void * window = null) { handle = webview_create(enableDebug, window); }

   void run() { webview_run(handle); }
   void html(string data) { webview_set_html(handle, data.toStringz); }

   void navigate(string url) { webview_navigate(handle, url.toStringz); }
   void unbindJs(string name) { webview_unbind(handle, name.toStringz); }
   void title(string title) { webview_set_title(handle, title.toStringz);}
   void size(int width, int height, int hints=WEBVIEW_HINT_NONE) { webview_set_size(handle, width, height, hints);}
   void terminate() { webview_terminate(handle); }
   void* window() { return webview_get_window(handle); }


   void eval(alias func = null)(string js, void* extra = null)
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
               EvalPayload *p = cast(EvalPayload*) extra;
               webview_unbind(p.handle, p.uuid.toStringz);
               static if (__traits(compiles, func(v[0], p.extra))) func(v[0], p.extra);
               else func(v[0]);
               p.destroy();
            }
         )
         (uuid, cast(void*)payload);

         eval(uuid ~ `(eval('` ~ js.escapeJs() ~ `'));`);
      }
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

   Elements bySelectorAll(string query)
   {
      return new Elements(this, "document.querySelectorAll('" ~ query.escapeJs() ~ "')");
   }


   Element bySelector(string query)
   {
      return new Element(this, "document.querySelector('" ~ query.escapeJs() ~ "')");
   }

   Element byId(string id)
   {
      return new Element(this, "document.getElementById('" ~ id.escapeJs() ~ "')");
   }

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

   static auto toDataUri(const ubyte[] bytes, string mimeType = "application/octet-stream")
   {
      import std.base64;
      return ("data:" ~ mimeType ~ ";base64," ~ Base64.encode(bytes));
   }

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

   void onInit(string js) { webview_init(handle, js.toStringz); }
   void onInit(alias func)()
   {
      import std.uuid;
      string uuid = "_init_" ~ randomUUID.toString().replace("-", "_");
      static void proxy(JSONValue[]) { func(); }
      bindJs!(proxy)(uuid);
      onInit(uuid ~ "();");
   }

   void respond(string seq, int status, JSONValue v) { webview_return(handle, seq.toStringz, status, v.toString.toStringz); }

   void bindJs(alias func)(void* extra) { bindJs!func( __traits(identifier, func), extra); }
   void bindJs(alias func)(string jsFunc = __traits(identifier, func), void* extra = null)
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


   static auto parseJsArgs(T...)(JSONValue[] v)
   {
      import std.typecons : Tuple;

      alias TUPLE = Tuple!T;
      TUPLE ret;
      bool 	fail;

      static foreach(idx; 0..TUPLE.length)
      {
         fail = false;
         if (idx < v.length)
         {
            try { mixin("ret[" ~ idx.to!string ~ "]") = v[idx].get!(typeof(TUPLE[idx])); }
            catch (Exception e) { fail = true; }
         }
         else fail = true;

         if (fail)
            mixin("ret[" ~ idx.to!string ~ "]") = typeof(TUPLE[idx]).init;
      }

      return ret;
   }

}

string escapeJs(string s, char stringDelimeter = '\'')
{
   return s.replace(`\`, `\\`).replace(stringDelimeter, `\` ~ stringDelimeter);
}


private:

enum string[string] mimeTypes =
[
   ".aac" : "audio/aac", ".abw" : "application/x-abiword", ".arc" : "application/x-freearc", ".avif" : "image/avif",
   ".bin" : "application/octet-stream", ".bmp" : "image/bmp", ".bz" : "application/x-bzip", ".bz2" : "application/x-bzip2",
   ".cda" : "application/x-cdf", ".csh" : "application/x-csh", ".css" : "text/css", ".csv" : "text/csv",
   ".doc" : "application/msword", ".docx" : "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
   ".eot" : "application/vnd.ms-fontobject", ".epub" : "application/epub+zip", ".gz" : "application/gzip",
   ".gif" : "image/gif", ".htm" : "text/html", ".html" : "text/html", ".ico" : "image/vnd.microsoft.icon",
   ".ics" : "text/calendar", ".jar" : "application/java-archive", ".jpeg" : "image/jpeg", ".jpg" : "image/jpeg",
   ".js" : "text/javascript", ".json" : "application/json", ".jsonld" : "application/ld+json", ".mid" : ".midi",
   ".mjs" : "text/javascript", ".mp3" : "audio/mpeg",".mp4" : "video/mp4", ".mpeg" : "video/mpeg", ".mpkg" : "application/vnd.apple.installer+xml",
   ".odp" : "application/vnd.oasis.opendocument.presentation", ".ods" : "application/vnd.oasis.opendocument.spreadsheet",
   ".odt" : "application/vnd.oasis.opendocument.text", ".oga" : "audio/ogg", ".ogv" : "video/ogg", ".ogx" : "application/ogg",
   ".opus" : "audio/opus", ".otf" : "font/otf", ".png" : "image/png", ".pdf" : "application/pdf", ".php" : "application/x-httpd-php",
   ".ppt" : "application/vnd.ms-powerpoint", ".pptx" : "application/vnd.openxmlformats-officedocument.presentationml.presentation",
   ".rar" : "application/vnd.rar", ".rtf" : "application/rtf", ".sh" : "application/x-sh", ".svg" : "image/svg+xml",
   ".swf" : "application/x-shockwave-flash", ".tar" : "application/x-tar", ".tif" : "image/tiff", ".tiff" : "image/tiff",
   ".ts" : "video/mp2t", ".ttf" : "font/ttf", ".txt" : "text/plain", ".vsd" : "application/vnd.visio", ".wasm" : "application/wasm",
   ".wav" : "audio/wav", ".weba" : "audio/webm", ".webm" : "video/webm", ".webp" : "image/webp", ".woff" : "font/woff", ".woff2" : "font/woff2",
   ".xhtml" : "application/xhtml+xml", ".xls" : "application/vnd.ms-excel", ".xlsx" : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
   ".xml" : "application/xml", ".xul" : "application/vnd.mozilla.xul+xml", ".zip" : "application/zip", ".3gp" : "video/3gpp",
   ".3g2" : "video/3gpp2", ".7z" : "application/x-7z-compressed"
];


alias webview_t = void*;

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

alias dispatchCallback = extern(C) void function(webview_t w, void* arg);

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
// the webview will open a new page - this initialization code will be
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

alias bindCallback = extern(C) void function (const char *seq, const char *req, void *arg);

// Removes a native C callback that was previously set by webview_bind.
extern(C)  void webview_unbind(webview_t w, const char *name);

// Responds to a binding call from the JS side. The ID/sequence number must
// match the value passed to the binding wb.handler in order to respond to the
// call and complete the promise on the JS side. A status of zero resolves
// the promise, and any other value rejects it. The result must either be a
// valid JSON value or an empty string for the primitive JS value "undefined".
extern(C)  void webview_return(webview_t w, const char *seq, int status, const char *result);