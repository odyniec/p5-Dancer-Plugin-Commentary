(function () {
    var selectors;

    if (__commentaryCfg.content_selector)
        selectors = [ __commentaryCfg.content_selector ];
    else
        selectors = [
            '.site .post'       // Jekyll
        ];

    for (var i = 0; i < selectors.length; i++) {
        if (document.querySelector(selectors[i])) {
            var post = document.querySelector(selectors[i]);

            var iframe = document.createElement('iframe');
            iframe.src = __commentaryBaseURI + '/includes/iframe.html' + '?l=' +
                encodeURIComponent(window.location.pathname);
            post.appendChild(iframe);

            iframe.style.width = '100%';
            iframe.style.borderWidth = '0';

            window.__commentaryIframeResize = function () {
                iframe.height = iframe.contentDocument.documentElement.scrollHeight;
            };
        }
    }
})();
