function addLoadEvent(func) {
  if (window.addEventListener) {
    window.addEventListener("load", func, false);
  } else if (window.attachEvent) {
    window.attachEvent("onload", func);
  } else { // fallback
    var old = window.onload;
    window.onload = function() {
      if (old) old();
      func();
    };
  }
}

function addSubmitEvent(form, func) {
  if (window.addEventListener) {
    form.addEventListener("submit", func, false);
  } else if (window.attachEvent) {
    form.attachEvent("onsubmit", func);
  } else { // fallback
    var old = form.onsubmit;
    form.submit = function() {
      if (old) old();
      func();
    };
  }
}

addLoadEvent(function() {
  var forms = document.getElementsByTagName("form");
  for(var i=0;i<forms.length;i++) {
    if (forms[i] && forms[i].className == "delete-form") {
      addSubmitEvent(forms[i], function(e) {
        e = e || window.event;
        if(!confirm("Are you sure you want to delete this gem?")) {
          e.preventDefault();
          e.returnValue = false;
        }
      });
    }
  }
});
