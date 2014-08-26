(function () {

function getScript(url, success) {
    var script = document.createElement('script'),
        head = document.getElementsByTagName('head')[0],
        done = false;

    script.src = url;

    script.onload = script.onreadystatechange = function() {
        if (!done && (!this.readyState || this.readyState == 'loaded' ||
            this.readyState == 'complete'))
        {
            done = true;
            success();
            script.onload = script.onreadystatechange = null;
            head.removeChild(script);
        }
    };
    
    head.appendChild(script);
}

function init(jQueryLoading, underscoreLoading) {
    if (!window.jQuery && !jQueryLoading) {
        /* No jQuery found -- let's grab it from the CDN */
        getScript('//code.jquery.com/jquery-1.11.1.min.js', function() {
            start();
        });
        return init(true, underscoreLoading);
    }

    if (!window._ && !underscoreLoading) {
        /* Same deal with Underscore.js */
        getScript('//cdnjs.cloudflare.com/ajax/libs/underscore.js/1.6.0/underscore-min.js', function() {
            start();
        });
        return init(jQueryLoading, true);
    }
}

function ago(v, f) {
    v = ~~((Date.now() - v)/1e3);
    var a, b = { second: 60, minute: 60, hour: 24, day: 7, week: 4.35,
        month: 12, year: 1e4 }, c;
 
    for (a in b) {
        c=v % b[a];
        if (!(v = (f||parseInt)(v / b[a])))
            return c + ' ' + (c-1 ? a + 's' : a);
    }
}

init();

var cfg = __commentaryCfg,
    started = false,
    tplHTML;

function tpl(name, data) {
    var $elem;

    if (($elem = $('#commentary-template-' + name, $(tplHTML))).length)
        return _.template($elem.html())(data);
    else
        return '';
}

function prepareComment(comment) {
    comment.date = (new Date(comment.timestamp * 1000)).toLocaleString();
    comment.fuzzy_date = ago(comment.timestamp * 1000) + ' ago';

    return comment; 
}

function start() {
    if (started)
        /* Already started! */
        return;

    if (!(window.jQuery && window._))
        /* Sorry, we need jQuery and Underscore to proceed */
        return;

    if (!tplHTML) {
        $.get('/commentary/includes/templates.html',
            function (html) {
                tplHTML = html;
                start();
            },
            'html'
        );
        return;
    }

    started = true;

    $('head').append(tpl('head'));

    /* We now need to determine if this is a comments-friendly page */
    var $parent;

    if (cfg.display_mode == 'iframe') {
        /* We're inside an iframe, so we already know that comments should be
           displayed on this page */
        $parent = $('body');
    }
    else {
        $parent = (function () {
            /* Jekyll's default layout has a .post inside .site */
            if ($('.site .post').length) return $('.site .post');
        })();
    }

    if ($parent) {
        /* We do have a $parent to attach comments to, so let's get them */
        $.get('/commentary/comments' + contentURL(), function (comments) {
            doComments($parent, comments);
        }, 'json');
    }
}

function contentURL() {
    return (cfg.display_mode == 'iframe' ? window.parent : window)
        .location.pathname;
}

function doComments($parent, comments) {
    var $comments = $(tpl('comments', { comments: comments }));

    /* Append comments section */
    $comments.appendTo($parent)

    $.each(comments, function (index, comment) {
        $comments.append(tpl('comment', { comment: prepareComment(comment) }));
    });

    $('.commentary-comments-header', $comments)
        .after(tpl('new-comment', { user: cfg.user }))
        .after(tpl('authentication', { auth: cfg.auth, user: cfg.user }));

    if (window.parent.__commentaryIframeResize)
        window.parent.__commentaryIframeResize();

    if (cfg.display_mode == 'iframe') {
        /* Authentication links don't like to be called from an iframe */
        $('#commentary-authentication a').click(function (e) {
            window.parent.location = $(this).attr('href');
            e.preventDefault();
            return false;
        });
    }

    $('#commentary-new-comment .commentary-comment-actions-submit').click(function () {
        $.post('/commentary/comments',
            {
                post_url: contentURL(),
                body: $('#commentary-new-comment .commentary-comment-body textarea').val(),
            },
            function (comment) {
                $comments.append(tpl('comment', {
                    comment: prepareComment(comment)
                }));
                $('.commentary-comments-count').text(
                    $('.commentary-comments .commentary-comment').length +
                        ' comment' + ($('.commentary-comments .commentary-comment').length == 1 ? '' : 's')
                );

                if (window.parent.__commentaryIframeResize)
                    window.parent.__commentaryIframeResize();
            },
            'json'
        );

        /* Clear the comment box */
        $('#commentary-new-comment .commentary-comment-body textarea').val('')
    });
}

})();
