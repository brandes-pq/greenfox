(:
 : -------------------------------------------------------------------------
 :
 : compile.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Compiles a greenfox schema and returns an augmented copy of the descriptor, plus
 : a context map. The context map consists of the context map contained by the
 : schema, extended/overwritten by the name-value pairs supplied as
 : external context. In the augmented descriptor, components with a component
 : reference are replaced with the referenced component, augmented with the
 : attributes and content elements of the referencing component.
 :
 : @param gfox a greenfox schema
 : @param externalContext a set of external variables
 :)
declare function f:compileGreenfox($gxdoc as element(gx:greenfox), 
                                   $externalContext as map(xs:string, item()*)) 
        as item()+ {
    let $context := map:merge(
        for $field in $gxdoc/gx:context/gx:field
        let $name := $field/@name/string()
        let $value := ($externalContext($name), $field/@value)[1]
        return
            map:entry($name, $value) 
    )
    let $gxdoc2 := f:compileGreenfoxRC($gxdoc, $context)
    let $gxdoc3 := f:compileGreenfox_addIds($gxdoc2)
    let $gxdoc4 := f:compileGreenfox_addIds2($gxdoc3)
    return
        ($gxdoc4, $context)
};

(:~
 : Recursive helper function of `f:compileGreenfox`.
 :
 : @param n a node of the greenfox schema currently processed.
 : @param context a set of external variables
 : @return the processing result
 :)
declare function f:compileGreenfoxRC($n as node(), $context as map(xs:string, item()*)) as node() {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:compileGreenfoxRC(., $context)}
    
    case element(gx:greenfox) return
        element {node-name($n)} {
            in-scope-prefixes($n)[string()] ! namespace {.} {namespace-uri-for-prefix(., $n)},
            $n/@* ! f:compileGreenfoxRC(., $context),
            if ($n/@xml:base) then () else attribute xml:base {base-uri($n)},
            $n/node() ! f:compileGreenfoxRC(., $context) 
        }
    case element() return
        element {node-name($n)} {
            in-scope-prefixes($n)[string()] ! namespace {.} {namespace-uri-for-prefix(., $n)},
            $n/@* ! f:compileGreenfoxRC(., $context),
            $n/node() ! f:compileGreenfoxRC(., $context)            
        }
        
    (: text - variable substitution :)
    case text() return text {f:substituteVars($n, $context, ())}
    
    (: attribute - variable substitution :)
    case attribute() return attribute {node-name($n)} {f:substituteVars($n, $context, ())}
    
    default return $n        
};

(:~
 : Inspects a component and returns another component which it references, or the original 
 : component if it does not reference another component. A reference is expressed by an 
 : @ref attribute. The referenced component is the checklib element with an @id attribute 
 : matching the value of @ref and with a local name matching the local name of the 
 : referencing component.
 :
 : @param gxComponent a component possibly referencing another component
 : @return the original component, if it does not have a reference, or the
 :   referenced component
 :)
declare function f:compileGreenfox_resolveReference($gxComponent as element()) as element() {
    if (not($gxComponent/@ref)) then $gxComponent else
    
    let $gxname := local-name($gxComponent)
    let $target := $gxComponent/root()//gx:checklib/*[$gxname eq local-name(.)][@id eq $gxComponent/@ref]
    return
        $target
};

(:~
 : Substitutes variable references with variable values. The references have the form ${name} or
 : @{name}. References using the dollar character are resolved using $context, and references
 : using the @ character are resolved using $callContext.
 :
 : @param s a string
 : @param context a context which is a map associating key strings with value strings
 : @param callContext a second context
 : @return a copy of the string with all variable references replaced with variable values
 :)
declare function f:substituteVars($s as xs:string?, 
                                  $context as map(xs:string, item()*), 
                                  $callContext as map(xs:string, item()*)?) 
        as xs:string? {
    let $s2 := f:substituteVarsAux($s, $context, '\$')
    return
        if (empty($callContext)) then $s2    
        else f:substituteVarsAux($s2, $callContext, '@') 
};

(:~
 : Auxiallary function of `f:substituteVars`.
 :
 : @param s a string
 : @param context a context which is a map associating key strings with value strings
 : @param callContext a second context
 : @return a copy of the string with all variable references replaced with variable values
 :) 
declare function f:substituteVarsAux($s as xs:string?, $context as map(xs:string, item()*), $prefixChar as xs:string) as xs:string? {
    let $sep := codepoints-to-string(30000)
    let $parts := replace($s, concat('^(.*?)(', $prefixChar, '\{.*?\})(.*)'), concat('$1', $sep, '$2', $sep, '$3'))
    return
        if ($parts eq $s) then $s
        else
            let $partStrings := tokenize($parts, $sep)
            let $prefix := $partStrings[1]
            let $varRef := $partStrings[2]
            let $postfix := $partStrings[3][string()]
            let $varName := $varRef ! substring(., 3) ! substring(., 1, string-length(.) - 1)
            let $varValue := $context($varName)            
            return
                concat($prefix, ($varValue, $varRef)[1], $postfix ! f:substituteVarsAux(., $context, $prefixChar))                
};

(:~
 : Maps the value of a string to a set of name-value pairs.
 :
 : @param params a string containing concatenated name-value pairs
 : @param domain the domain folder
 : @return a map expressing the pairs a key-value pairs
 :)
declare function f:externalContext($params as xs:string?, $domain as xs:string?) as map(xs:string, item()*) {
    let $nvpairs := tokenize($params, '\s*;\s*')
    let $raw :=
        map:merge(
            $nvpairs ! 
            map:entry(replace(., '\s*=.*', ''), 
                      replace(., '^.*?=\s*', '')
            )
        )
    return
        if ($domain) then
            if (map:contains($raw, 'domain')) then
                error(QName((), 'INVALID_ARG'),
                    "When using params with a 'domain' field, you must not ',
                     use the 'domain' parameter; aborted.'") 
            else
                map:put($raw, 'domain', $domain)
        else $raw        
};

declare function f:compileGreenfox_addIds($gfox as element(gx:greenfox)) {
    copy $gfox_ := $gfox
    modify
        let $elems := ($gfox_//*) except ($gfox_/gx:context/descendant-or-self::*)
        for $elem in $elems
        group by $localName := local-name($elem)
        return
            for $e at $pos in $elem
            let $idAtt := $e/@id
            let $idValue := ($idAtt, concat($localName, '_', $pos))[1]
            let $idName :=
                switch($localName)
                case 'mediatype' return 'constraintID'
                default return 'id'
            let $furtherAtts:=
                typeswitch($elem[1])
                case element(gx:file) | element(gx:folder) return
                    attribute resourceShapeID {$idValue}
                case element(gx:xpath) | element(gx:foxpath) return
                    attribute valueShapeID {$idValue}
                default return ()
            return (
                $idAtt/(delete node .),
                insert node ($furtherAtts, attribute {$idName} {$idValue}) as first into $e                
            )                
    return $gfox_                
};

declare function f:compileGreenfox_addIds2($gfox as element(gx:greenfox)) {
    f:compileGreenfox_addIds2RC($gfox)
};

declare function f:compileGreenfox_addIds2RC($n as node()) {
    typeswitch($n)
    case element(gx:file) | element(gx:folder) return
        element {node-name($n)} {
            in-scope-prefixes($n)[string()] ! namespace {.} {namespace-uri-for-prefix(., $n)},
            $n/@* ! f:compileGreenfox_addIds2RC(.),
            $n/node() ! f:compileGreenfox_addIds2RC(.)
        }
    case element(gx:targetSize) return
        (: let $resourceShapeID := $n/ancestor::*[self::gx:file, self::gx:folder][2]/@resourceShapeID :)
        let $resourceShapeID := $n/ancestor::*[self::gx:file, self::gx:folder][1]/@resourceShapeID
        return
            element {node-name($n)} {
                in-scope-prefixes($n)[string()] ! namespace {.} {namespace-uri-for-prefix(., $n)},
                $resourceShapeID,
                $n/@* ! f:compileGreenfox_addIds2RC(.),
                $n/node() ! f:compileGreenfox_addIds2RC(.)
            }
    case element() return
        let $resourceShapeID :=
            if ($n/(self::gx:xpath,
                    self::gx:foxpath,
                    self::gx:fileSize, 
                    self::gx:lastModified, 
                    self::gx:mediatype,
                    self::gx:folderContent,
                    self::gx:xsdValid
               )) then  
                $n/ancestor::*[self::gx:file, self::gx:folder][1]/@resourceShapeID
            else ()                
        return
            element {node-name($n)} {
                in-scope-prefixes($n)[string()] ! namespace {.} {namespace-uri-for-prefix(., $n)},
                $resourceShapeID,
                $n/@* ! f:compileGreenfox_addIds2RC(.),
                $n/node() ! f:compileGreenfox_addIds2RC(.)
            }
    default return $n        
};

