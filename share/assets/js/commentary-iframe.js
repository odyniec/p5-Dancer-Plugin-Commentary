(function () {
    var enableSelectors, contentSelectors;

    if (__commentaryCfg.content_selector)
        contentSelectors = [ __commentaryCfg.content_selector ];
    else
        contentSelectors = [
            '.site .post'       // Jekyll
        ];

    if (__commentaryCfg.enable_selector)
        enableSelectors = [ __commentaryCfg.enable_selector ];
    else
        enableSelectors = contentSelectors;

    for (var i = 0; i < enableSelectors.length; i++) {
        if (document.querySelector(enableSelectors[i])) {
            var post;

            for (var j = 0; j < contentSelectors.length; j++)
                if (post = document.querySelector(contentSelectors[i]))
                    /* Content element found */
                    break;

            if (!post)
                /* Can't find content -- let's bail out */
                break;

            var iframe = document.createElement('iframe');
            iframe.src = __commentaryBaseURI + '/includes/iframe.html' + '?l=' +
                encodeURIComponent(window.location.pathname);
            post.appendChild(iframe);

            iframe.style.width = '100%';
            iframe.style.borderWidth = '0';

            window.__commentaryIframeResize = function () {
                iframe.height = iframe.contentDocument.documentElement.scrollHeight;
            };

            break;
        }
    }
})();
