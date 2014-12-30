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

function ago(val) {
    val = 0 | (Date.now() - val) / 1000;
    var unit, length = { second: 60, minute: 60, hour: 24, day: 7, week: 4.35,
        month: 12, year: 10000 }, result;
 
    for (unit in length) {
        result = val % length[unit];
        if (!(val = 0 | val / length[unit]))
            return result + ' ' + (result-1 ? unit + 's' : unit);
    }
}

var cfg = __commentaryCfg,
    started = false,
    prefix = cfg.prefix,
    tplHTML;

/* We need jQuery */
addPrerequisite({
    url: '//code.jquery.com/jquery-1.11.1.min.js',
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
    comment.date = (new Date(comment.created_timestamp * 1000)).toLocaleString();
    comment.fuzzy_date = ago(comment.created_timestamp * 1000) + ' ago';

    if (comment.fuzzy_date == '0 seconds ago')
        comment.fuzzy_date = 'just now';

    return comment; 
}

function start() {
    if (started)
        /* Already started! */
        return;

    if (!tplHTML) {
        /* Need to load templates */
        $.get(prefix + '/includes/templates.html',
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
            /* FIXME: Make use of cfg.content_selector */
        })();
    }

    if ($parent) {
        /* We do have a $parent to attach comments to, so let's get them */
        $.post(
            prefix + '/search/comments',
            JSON.stringify({ 
                post_url: contentURL()
            }),
            function (comments) {
                doComments($parent, comments);
            },
            'json'
        );
    }
}

function adjustIframe() {
    if (window.parent.__commentaryIframeResize)
        window.parent.__commentaryIframeResize();    
}

function contentURL() {
    return (cfg.display_mode == 'iframe' ? window.parent : window)
        .location.pathname;
}

function doComments($parent, comments) {
    var $comments = $(tpl('comments', { comments: comments }));

    /* Append comments section */
    $comments.appendTo($parent)

    /* Sort comments in chronological order */
    /* TODO: We might want to do this in the API */
    comments.sort(function (a, b) {
        return a.created_timestamp - b.created_timestamp;
    });

    $.each(comments, function (index, comment) {
        $comments.append(tpl('comment', { comment: prepareComment(comment) }));
    });

    /* Are non-authenticated comments allowed? */
    var nonAuthAllowed = false;

    $.each(cfg.auth.methods, function (i, method) {
        if (method.name == 'None') {
            nonAuthAllowed = true;
            return false;
        }

        return true;
    });

    $('.commentary-comments-header', $comments)
        .after(tpl('new-comment', {
            auth:             cfg.auth,
            non_auth_allowed: nonAuthAllowed,
            user:             cfg.user
        }))
        .after(tpl('authentication', {
            auth: cfg.auth,
            user: cfg.user
        }));

    adjustIframe();

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
            $('#commentary-new-comment-captcha')[0],
            {
                theme: cfg.recaptcha.theme || 'clean',
                callback: function () {
                    /* If in an iframe, adjust size after reCAPTCHA is loaded */
                    adjustIframe();
                }
            }
        );

    $('#commentary-new-comment .commentary-comment-actions-submit').click(function () {
        var post_data = {
            post_url: contentURL(),
            body: $('#commentary-new-comment .commentary-comment-body textarea').val(),
        };

        if (!(cfg.user.auth instanceof Object)) {
            post_data['author'] = {
                name: $('#commentary-new-comment .commentary-comment-author ' +
                    'input').val()
            };
        }

        if (cfg.recaptcha) {
            post_data['recaptcha_challenge'] = Recaptcha.get_challenge();
            post_data['recaptcha_response'] = Recaptcha.get_response();
        }

        $.post(prefix + '/comments', JSON.stringify(post_data),
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

                /* Refresh captcha (if shown) */
                if (window.Recaptcha)
                    Recaptcha.reload();

                /* Clear the comment box */
                $('#commentary-new-comment .commentary-comment-body textarea')
                    .val('')
                /* Disable the "Add Comment" button */
                $('#commentary-new-comment .commentary-comment-actions-submit')
                    .prop('disabled', true);

                adjustIframe();
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
    });

    /* Enable the "Add comment" button when something is entered into the
       textarea */
    $('#commentary-new-comment .commentary-comment-body textarea')
        .on('change keyup paste',
            function() {
                $('#commentary-new-comment .commentary-comment-actions-submit')
                    .prop('disabled', !$(this).val().match(/\S/));
            }
        );

    /* Initially disable the "Add comment" button */
    $('#commentary-new-comment .commentary-comment-actions-submit')
        .prop('disabled', true);
}

var quickShowTimers = {};

/* Show an element with an effect similar to slideDown, then hide it two seconds
   after a key is pressed or mouse cursor moved. */
function quickShow(element) {
    return $(element).animate(
        {
            height: 'show',
            margin: 'show',
        },
        {
            duration: 'fast',
            progress: function () {
                    adjustIframe();
            },
            complete: function () {
                $(document).one('keydown mousemove', function () {
                    if (quickShowTimers[element]) {
                        clearTimeout(quickShowTimers[element]);
                    }

                    quickShowTimers[element] = setTimeout(function () {
                        $('.commentary-message').animate({
                                height: 'hide',
                                margin: 'hide',
                            },
                            {
                                duration: 'fast',
                                progress: function () {
                                    adjustIframe();
                                },
                                complete: function () {
                                    adjustIframe();
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
