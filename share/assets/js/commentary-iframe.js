(function () {
    if (document.querySelector('.site .post')) {
        var post = document.querySelector('.site .post');

        var iframe = document.createElement('iframe');
        iframe.src = __commentaryBaseURI + '/includes/iframe.html' + '?l=' +
            encodeURIComponent(window.location.pathname);
        post.appendChild(iframe);

        iframe.style.width = '100%';
        iframe.style.borderWidth = '0';
    }

    window.__commentaryIframeResize = function () {
        iframe.height = iframe.contentDocument.documentElement.scrollHeight;
    };
})();
