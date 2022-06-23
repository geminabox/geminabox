[].forEach.call(document.querySelectorAll("form.delete-form"), function(el) {
  el.addEventListener("submit", function(ev) {
    if (!confirm("Are you sure you want to delete this gem?")) {
      ev.preventDefault();
    }
  }, false);
});
