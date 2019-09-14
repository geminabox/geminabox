/*!
 * RestfulizerJs 0.1
 * http://ifnot.github.io/RestfulizerJs/
 *
 * Use jQuery
 * http://jquery.com/
 *
 * Inspired by froztbytes works :
 * https://gist.github.com/froztbytes/5385905
 *
 * Copyright 2014 Anael Favre and other contributors
 * Released under the MIT license
 * https://raw.github.com/Ifnot/RestfulizerJs/master/LICENCE
 */

(function ($) {
    $.fn.extend({
        restfulizer: function (options) {
            var defaults = $.extend({
                parse: false,
                target: null,
                method: "POST"
            }, options);

            return $(this).each(function () {
                var options = $.extend({}, defaults);
                var self = $(this);

                // Try to get data-param into options
                if (typeof(self.attr('data-method')) != "undefined") {
                    options.method = self.attr('data-method').toUpperCase();
                }

                if (typeof(self.attr('href')) != "undefined") {
                    options.target = self.attr('href');
                }

                // Parse href parameters and create an input for each parameter
                var inputs = "";

                if (options.parse) {
                    var paramsIndex = options.target.indexOf("?");
                    var hasParams = (paramsIndex > -1);

                    if (hasParams) {
                        var params = options.target.substr(paramsIndex + 1).split('#')[0].split('&');
                        options.target = options.target.substr(0, paramsIndex);

                        for (var i = 0; i < params.length; i++) {
                            var pair = params[i].split('=');
                            inputs += "	<input type='hidden' name='" + decodeURIComponent(pair[0]) + "' value='" + decodeURIComponent(pair[1]) + "'>\n";
                        }
                    }
                }

                if (options.method == 'GET' || options.method == 'POST') {
                    var form = "\n" +
                        "<form action='" + options.target + "' method='" + options.method + "' style='display:none'>\n" +
                        inputs +
                        "</form>\n";
                }
                else {
                    var form = "\n" +
                        "<form action='" + options.target + "' method='POST' style='display:none'>\n" +
                        "	<input type='hidden' name='_method' value='" + options.method + "'>\n" +
                        inputs +
                        "</form>\n";
                }

                self.append(form)
                    .removeAttr('href')
                    .attr('style', 'cursor:pointer;')
                    .attr('onclick', '$(this).find("form").submit();');
            });
        }
    });
})(jQuery);
