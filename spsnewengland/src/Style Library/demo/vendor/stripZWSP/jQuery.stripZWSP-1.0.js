/*
 * The Sharepoint Rich HTML editor leaves ZERO WIDTH SPACE chracters (&#8203;
 * or \u200B) all over the place. This trawls through the HTML you pass in and 
 * strips out zero width space characters from text nodes within.
 *
 * http://blog.bugrapostaci.com/2014/02/02/publishing-field-encoding-extra-questionmark-charecters-actually-acsii-8203-zero-width-space/
 *
 * This trawls through the HTML you pass in and strips out zero width space 
 * characters from text nodes within.
 *
 * $("selector").stripZWSP();
 *
 * You can optionally pass in an options object to configure what characters
 * to find, what to replace them with, whether to show debug messages, etc:
 *
 * $("selector").stripZWSP({
 *     "debug": true,
 *     "replacementChar" : "Z"
 * });
 *
 * Olly Hodgson, 07-Jan-2015.
 */
(function ($) {

    var methods = {

        init: function (options) {

            var settings = $.extend({
                'replacementRegex': /\u200B/g, // The characters we want to match
                'replacementChar': '',        // The character to replace them with
                'includeWhitespaceNodesWhenGettingTextNodes': true,      // Include whitespace nodes when getting text nodes
                'debug': false      // Show debug messages. See methods.debugMessage() function
            }, options),
                inDesignMode = $("#MSOLayout_InDesignMode").val();

            /* Return early if we're in edit mode */
            if (inDesignMode === "1") {
                methods.debugMessage(settings, "In design mode, returning early");
                return this;
            }

            /* Loop through all of the elements passed in */
            return this.each(function (i) {

                /* Grab all of the text nodes */
                var textNodes = methods.getTextNodesIn(this, settings.includeWhitespaceNodesWhenGettingTextNodes),
                    textNodesLength = textNodes.length,
                    textNodeContent = '';

                methods.debugMessage(settings, "textNodesLength:", textNodesLength);

                if (textNodesLength > 0) {
                    /* Replace settings.replacementRegex with settings.replacementChar in all text nodes */
                    for (var i = 0; i < textNodesLength; i++) {
                        textNodeContent = textNodes[i].nodeValue.replace(settings.replacementRegex, settings.replacementChar);
                        textNodes[i].nodeValue = textNodeContent;
                    }
                }

            });

        },

        /*
         * methods.getTextNodesIn(node, includeWhitespaceNodes)
         * Returns all of the text nodes which are children
         * of a given DOM element.
         * Adapted from: http://stackoverflow.com/a/4399718/13019
         *
         * methods.getTextNodesIn(this[, true|false]);
         */
        getTextNodesIn: function (node, includeWhitespaceNodes) {
            var textNodes = [], nonWhitespaceMatcher = /\S/;

            function getTextNodes(node) {
                if (node.nodeType == 3) {
                    if (includeWhitespaceNodes || nonWhitespaceMatcher.test(node.nodeValue)) {
                        textNodes.push(node);
                    }
                } else {
                    for (var i = 0, len = node.childNodes.length; i < len; ++i) {
                        getTextNodes(node.childNodes[i]);
                    }
                }
            }

            getTextNodes(node);
            return textNodes;
        },

        /*
         * If settings.debug === true, output to the console
         * methods.debugMessage(settings, "message", "message" [, etc]);
         */
        debugMessage: function (options) {
            if (options.debug === true) {
                if (window.console && console.info) {
                    return console.info("stripZWSP:", arguments[1], Array.prototype.slice.call(arguments));
                }
            }
        }

    };

    $.fn.stripZWSP = function (method) {
        if (methods[method]) {
            return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
        } else if (typeof method === 'object' || !method) {
            return methods.init.apply(this, arguments);
        } else {
            $.error('Method ' + method + ' does not exist on jQuery.stripZWSP');
        }
    };

})(jQuery);

$(document).ready(function () {
    jQuery(".ms-rtestate-field").stripZWSP();
});