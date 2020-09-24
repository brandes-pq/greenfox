(:
 : greenfox - 
 :
 : @version 2020-09-22T22:43:45.404+02:00 
 :)

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_request.xqm";

import module namespace m="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxMain.xqm";

declare namespace z="http://www.greenfox.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

declare variable $request as xs:string external;

declare variable $req as element() := tt:loadRequest($request, $m:toolScheme);

m:execOperation($req)
    