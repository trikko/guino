

window.onload = (event) => {
   d_function("one", 2, "three");
   d_promise(1,2).then( result =>  { document.getElementById("result").innerText = result; });
};


function js_function(arg) { document.getElementById("from_js").innerText = arg; }
