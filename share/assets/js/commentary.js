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

var prerequisites = [];

function addPrerequisite(prerequisite) {
    prerequisites[prerequisites.length] = prerequisite;
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

var cfg = __commentaryCfg,
    started = false,
    prefix = cfg.prefix,
    tplHTML;

/* We need jQuery */
addPrerequisite({
    url: '//code.jquery.com/jquery-1.11.1.min.js',
    success: function () {
        /* We now have jQuery, let's use its .get method to grab templates */
        $.get(prefix + '/includes/templates.html',
            function (html) {
                tplHTML = html;
                start();
            },
            'html'
        );
    },
    check: function () { return window.jQuery; }
});
/* And Underscore.js */
addPrerequisite({
    url: '//cdnjs.cloudflare.com/ajax/libs/underscore.js/1.6.0/underscore-min.js',
    check: function () { return window._; }
});
/* We might also need reCAPTCHA */
if (cfg.recaptcha)
    addPrerequisite({
        url: '//www.google.com/recaptcha/api/js/recaptcha_ajax.js',
        check: function () { return window.Recaptcha; }
    });

/* Load all prerequisites */
for (var i = 0; i < prerequisites.length; i++) {
    getScript(prerequisites[i].url,
        (function (data) {
            if (this.success)
                this.success(data);

            for (var i = 0; i < prerequisites.length; i++) {
                if (!prerequisites[i].check())
                    return;
            }

            /* Yay, all prerequisites loaded -- start up! */
            start();
        }).bind(prerequisites[i])
    );
}

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

    if (!tplHTML)
        /* Templates are still loading */
        return;

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
        $.post(
            prefix + '/search/comments',
            { 
                post_url: contentURL()
            },
            function (comments) {
                doComments($parent, comments);
            },
            'json'
        );
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

    /* Show reCAPTCHA */
    if (cfg.recaptcha)
        Recaptcha.create(cfg.recaptcha.public_key,
            $('#commentary-new-comment .commentary-comment-captcha')[0],
            {
                theme: cfg.recaptcha.theme || 'clean',
                callback: Recaptcha.focus_response_field
            }
        );

    $('#commentary-new-comment .commentary-comment-actions-submit').click(function () {
        var post_data = {
            post_url: contentURL(),
            body: $('#commentary-new-comment .commentary-comment-body textarea').val(),
        };

        if (cfg.recaptcha) {
            post_data['recaptcha_challenge'] = Recaptcha.get_challenge();
            post_data['recaptcha_response'] = Recaptcha.get_response();
        }

        $.post(prefix + '/comments', post_data,
            function (comment) {
                $comments.append(
                    $(tpl('comment', {
                        comment: prepareComment(comment)
                    })).hide().fadeIn('fast')
                );

                $('.commentary-message').removeClass('commentary-message-error');
                $('.commentary-message').addClass('commentary-message-info');
                $('.commentary-message').html(
                    '<span class="fa fa-check-circle" /> New comment posted!'
                );
                quickShow($('.commentary-message'));

                $('.commentary-comments-count').text(
                    $('.commentary-comments .commentary-comment').length +
                        ' comment' + ($('.commentary-comments .commentary-comment').length == 1 ? '' : 's')
                );

                if (window.parent.__commentaryIframeResize)
                    window.parent.__commentaryIframeResize();
            },
            'json'
        )
        .fail(function (xhr) {
            var errors = xhr.responseJSON;
            $('.commentary-message').removeClass('commentary-message-info');
            $('.commentary-message').addClass('commentary-message-error');
            $('.commentary-message').html(
                '<span class="fa fa-exclamation-circle" /> ' + errors[0]['msg']
            );
            quickShow($('.commentary-message'));
        });

        /* Clear the comment box */
        $('#commentary-new-comment .commentary-comment-body textarea').val('')
    });
}

var quickShowTimers = {};

/* Show an element with an effect similar to slideDown, then hide it two seconds
   after a key is pressed or mouse cursor moved. */
function quickShow(element) {
    return $(element).animate(
        {
            height: 'show',
            marginBottom: 'show',
            marginLeft: 'show',
            marginRight: 'show',
            marginTop: 'show',
        },
        {
            duration: 'fast',
            progress: function () {
                if (window.parent.__commentaryIframeResize)
                    window.parent.__commentaryIframeResize();
            },
            complete: function () {
                $(document).one('keydown mousemove', function () {
                    if (quickShowTimers[element]) {
                        clearTimeout(quickShowTimers[element]);
                    }

                    quickShowTimers[element] = setTimeout(function () {
                        $('.commentary-message').animate({
                                height: 'hide',
                                marginBottom: 'hide',
                                marginLeft: 'hide',
                                marginRight: 'hide',
                                marginTop: 'hide',
                            },
                            {
                                duration: 'fast',
                                progress: function () {
                                    if (window.parent.__commentaryIframeResize)
                                        window.parent.__commentaryIframeResize();
                                },
                                complete: function () {
                                    if (window.parent.__commentaryIframeResize)
                                        window.parent.__commentaryIframeResize();                                    
                                }
                            }
                        );
                    }, 2000);
                });
            }
        }
    );
}

})();
