import module namespace m="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxMain.xqm";

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_request.xqm";

declare variable $arguments as xs:string external;

declare variable $args as xs:string* external := tokenize(normalize-space($arguments), ' ');

declare variable $nl := '&#xa;';

declare variable $rtype-shortcuts := map {
    'r': 'redTree',
    'w': 'whiteTree'
};

declare variable $usage := string-join((
    '',
    'Usage: greenfox [-f w] schema [domain]',
    '',
    'schema: Greenfox schema file; relative or absolute path',
    'domain: Validation root resource; relative or absolute path',
    '',
    ' -t      : the report type; w=whiteTree; r=redTree',
    '',
()), $nl);

(:~
    Returns either a map of the parsed arguments or an error string
:)
declare function local:parse-args($args, $argn, $result) {
    if (empty($args)) then $result
    else

    let $arg := $args[1]
    return

    (: handle options :)
    if (starts-with($arg, '-'))
    then switch ($arg)

        case '-w' return
            local:parse-args(subsequence($args, 2), $argn, map:merge((map {'RTYPE': 'whiteTree' }, $result)))

        case '-r' return
            local:parse-args(subsequence($args, 2), $argn, map:merge((map {'RTYPE': 'redTree' }, $result)))

        case '-t' return
            let $rtype := $args[2]
            return
            if ($rtype = map:keys($rtype-shortcuts))
            then local:parse-args(subsequence($args, 3), $argn, map:merge((map {'RTYPE': map:get($rtype-shortcuts, $rtype)}, $result)))
            else string-join((
                'Unknown rtype: ' || $rtype,
                'Aborted.',
                ()), $nl)

        default return string-join((
            'Unknown option: ' || $args[1],
            '   -r -w',
            'Aborted.',
            ()), $nl)

    (: handle arguments :)
    else switch ($argn)

        case 1 return
            if ($arg = '?')
            then map { 'usage': true() }
            else local:parse-args(subsequence($args, 2), $argn + 1, map:merge((map {'schema': $arg}, $result)))

        case 2 return
            local:parse-args(subsequence($args, 2), $argn + 1, map:merge((map {'domain': $arg}, $result)))

        default return
            (: ignore additional arguments :)
            local:parse-args(subsequence($args, 2), $argn + 1, $result)
};

(:~
    build a topicTool request string
:)
declare function local:build-request($parsed-args as map(xs:string, xs:string)) as xs:string {
    'val?gfox=' || $parsed-args?schema
    || string-join((
        $parsed-args?RTYPE ! (',reportType=' || .),
        $parsed-args?domain ! (',domain=' || .),
    ()))
};


(: ~~~~~~~~~~~ main logic ~~~~~~~~~~~ :)

let $args := local:parse-args($args, 1, map {})
return typeswitch ($args)

    case $err as xs:string return
        error(QName('', 'error'), $err)

    default return
        if ($args?usage) then $usage
        else local:build-request($args)
            => tt:loadRequest($m:toolScheme)
            => m:execOperation()
