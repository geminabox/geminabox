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

  var CHECK_ICON =
    '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" ' +
    'stroke="#3fa34d" stroke-width="2.5" stroke-linecap="round" ' +
    'stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text);
      return;
    }
    // Plain-http deployments have no navigator.clipboard.
    var scratch = document.createElement("textarea");
    scratch.value = text;
    scratch.setAttribute("readonly", "");
    scratch.style.position = "absolute";
    scratch.style.left = "-9999px";
    document.body.appendChild(scratch);
    scratch.select();
    try {
      document.execCommand("copy");
    } catch (e) {}
    document.body.removeChild(scratch);
  }

  [].forEach.call(document.querySelectorAll("button.copy-command"), function (button) {
    var originalIcon = button.innerHTML;
    button.addEventListener(
      "click",
      function () {
        var code = button.closest(".version-row").querySelector("code");
        copyText(code.textContent.replace(/\s+/g, " ").trim());
        button.innerHTML = CHECK_ICON;
        button.classList.add("copied");
        clearTimeout(button.__copyTimer);
        button.__copyTimer = setTimeout(function () {
          button.innerHTML = originalIcon;
          button.classList.remove("copied");
        }, 1200);
      },
      false
    );
  });

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
