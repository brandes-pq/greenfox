(:
 : -------------------------------------------------------------------------
 :
 : expressionEvaluator.xqm - functions for evaluating expressions
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "foxpathUtil.xqm",
    "greenfoxUtil.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Evaluates an XPath expression.
 :
 : @param xpath an XPath expression
 : @param contextItem the context item
 : @param context the evaluation context
 : @param addVariableDeclarations if true, a prolog is added to the query which declares the external variables
 : @param addContextItem if true, the context item is added to the context with key ''
 : @return the expression value
 :)
declare function f:evaluateXPath($xpath as xs:string, 
                                 $contextItem as item()?, 
                                 $context as map(xs:QName, item()*),
                                 $addVariableDeclarations as xs:boolean,
                                 $addContextItem as xs:boolean)
        as item()* {
    let $xpathUsed :=
        if (not($addVariableDeclarations)) then $xpath
        else i:finalizeQuery($xpath, map:keys($context))
    let $contextUsed :=
        if (not($addContextItem)) then $context
        else map:put($context, '', $contextItem)
    return xquery:eval($xpathUsed, $contextUsed)
};

declare function f:evaluateSimpleXPath($xpath as xs:string, 
                                       $contextItem as item()?)
        as item()* {
    xquery:eval($xpath, map{'': $contextItem})        
};


(:~
 : Evaluates a foxpath expression.
 :
 : @param foxpath a foxpath expression
 : @param contextItem the context item
 : @param context the evaluation context
 : @param addVariableDeclarations if true, a prolog is added to the query which declares the external variables
 : @return the expression value
 :)
declare function f:evaluateFoxpath($foxpath as xs:string, 
                                   $contextItem as item()?, 
                                   $context as map(xs:QName, item()*),
                                   $addVariableDeclarations as xs:boolean)
        as item()* {
    let $isContextUri := not($contextItem instance of node())
    let $foxpathOptions := i:getFoxpathOptions($isContextUri)
    let $foxpathAugmented :=
        if (not($addVariableDeclarations)) then $foxpath
        else
            let $candidateBindings := map:keys($context) ! ( 
                if (. instance of xs:string or . instance of xs:untypedAtomic) then . 
                else local-name-from-QName(.))
            let $requiredBindings := i:determineRequiredBindingsFoxpath($foxpath, $candidateBindings)
            return i:finalizeQuery($foxpath, $requiredBindings)
            
    (: ensure that context keys are QNames :)            
    let $context :=
        if ($context instance of map(xs:QName, item()*)) then $context
        else
            map:merge(
                for $key in map:keys($context)
                let $value := $context($key)
                let $storeKey := if ($key instance of xs:QName) then $key else QName((), $key)
                return map:entry($storeKey, $value) 
            )
    return tt:resolveFoxpath($foxpathAugmented, $foxpathOptions, $contextItem, $context)
};

(:~
 : Evaluates a foxpath expression.
 :
 : @param foxpath a foxpath expression
 : @param context the context item
 : @return the expression value
 :)
declare function f:evaluateFoxpath($foxpath as xs:string, $contextItem as item()?)
        as item()* {
    f:evaluateFoxpath($foxpath, $contextItem, (), false())
};

declare function f:parseFoxpath($foxpath as xs:string)
        as item()* {
    let $foxpathOptions := i:getFoxpathOptions(true()) 
    return tt:parseFoxpath($foxpath, $foxpathOptions)
};

(:~
 : Augments an XPath or foxpath expression by adding a prolog containing
 : (a) a namespace declaration for prefix 'gx', (b) external variable
 : bindings for the given variable names.
 :
 : @param query the expression to be augmented
 : @param contextNames the names of the external variables
 : @return the augmented expression
 :)
declare function f:finalizeQuery($query as xs:string, 
                                 $contextNames as xs:anyAtomicType*)
        as xs:string {
    let $prolog := ( 
'declare namespace gx="http://www.greenfox.org/ns/schema";',
for $contextName in $contextNames 
let $varName := 
    if ($contextName instance of xs:QName) then string-join((prefix-from-QName($contextName), local-name-from-QName($contextName)), ':')     
    else $contextName
    return concat('declare variable $', $varName, ' external;')
    ) => string-join('&#xA;')
    return concat($prolog, '&#xA;', $query)
};

