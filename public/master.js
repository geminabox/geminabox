(function () {
  var dialog = document.getElementById("delete-confirm");

  function confirmationText(form) {
    var name = form.getAttribute("data-gem-name");
    var version = form.getAttribute("data-version");
    var platform = form.getAttribute("data-platform");

    if (!name || !version) {
      return {
        title: "Permanently delete this version from the server?",
        body:
          "This can't be undone, and projects that depend on this exact " +
          "version will no longer be able to install it. The version number " +
          "stays available, so it can be uploaded again afterward."
      };
    }

    var full = name + " " + version;
    if (platform && !/^ruby/i.test(platform)) {
      full += " (" + platform + ")";
    }
    return {
      title: "Permanently delete " + full + " from this server?",
      body:
        "This can't be undone, and projects that depend on this exact " +
        "version will no longer be able to install it. The version number " +
        "itself stays available: you can upload a new " + name + " " +
        version + " afterward."
    };
  }

  function openDialog(form) {
    var text = confirmationText(form);
    dialog.querySelector("h3").textContent = text.title;
    dialog.querySelector("p").textContent = text.body;
    dialog.showModal();

    dialog.querySelector("button.danger").onclick = function () {
      dialog.close();
      form.submit();
    };
  }

  if (dialog) {
    dialog.querySelector("button.cancel").addEventListener(
      "click",
      function () {
        dialog.close();
      },
      false
    );
    // A click on the backdrop targets the dialog element itself.
    dialog.addEventListener(
      "click",
      function (ev) {
        if (ev.target === dialog) {
          dialog.close();
        }
      },
      false
    );
  }

  [].forEach.call(document.querySelectorAll("form.delete-form"), function (form) {
    form.addEventListener(
      "submit",
      function (ev) {
        if (dialog && typeof dialog.showModal === "function") {
          ev.preventDefault();
          openDialog(form);
        } else {
          var text = confirmationText(form);
          if (!confirm(text.title + "\n\n" + text.body)) {
            ev.preventDefault();
          }
        }
      },
      false
    );
  });
})();
