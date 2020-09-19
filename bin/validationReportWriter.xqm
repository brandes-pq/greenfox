(:
 : -------------------------------------------------------------------------
 :
 : validationReportWriter.xqm - functions producing validation reports
 :
 : -------------------------------------------------------------------------
 :)
 

module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_request.xqm",
   "tt/_reportAssistent.xqm",
   "tt/_errorAssistent.xqm",
   "tt/_log.xqm",
   "tt/_nameFilter.xqm",
   "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "compile.xqm",
   "log.xqm",
   "greenfoxEditUtil.xqm",
   "greenfoxUtil.xqm",
   "systemValidator.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Writes a validation report.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:writeValidationReport($gfox as element(gx:greenfox)+,
                                         $domain as element(gx:domain),
                                         $results as element()*, 
                                         $reportType as xs:string, 
                                         $format as xs:string,
                                         $options as map(*),
                                         $context as map(xs:string, item()*))
        as item()* {
    switch($reportType)
    case "white" return f:writeValidationReport_raw($reportType, $gfox, $domain, $context, $results, $format, $options)
    case "red" return f:writeValidationReport_raw($reportType, $gfox, $domain, $context, $results, $format, $options)
    case "whiteTree" return f:writeValidationReport_whiteTree($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "redTree" return f:writeValidationReport_redTree($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "sum1" return f:writeValidationReport_sum($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "sum2" return f:writeValidationReport_sum($gfox, $domain, $context, $results, $reportType, $format, $options)
    case "sum3" return f:writeValidationReport_sum($gfox, $domain, $context, $results, $reportType, $format, $options)    
    case "std" return f:writeValidationReport_whiteTree($gfox, $domain, $context, $results, $reportType, $format, $options)    
    default return error(QName((), 'INVALID_ARG'), concat('Unexpected validation report type: ', "'", $reportType, "'",
        '; value must be one of: raw, whiteTree, redTree.'))
};

declare function f:writeValidationReport_raw(
                                        $reportType as xs:string,
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $format as xs:string,
                                        $options as map(*))
        as item()* {
    let $gfoxSourceURI := $gfox[1]/@xml:base
    let $greenfoxURI := $gfox[1]/@greenfoxURI
    let $useResults := 
        if ($reportType eq 'white') then $results 
        else if ($reportType eq 'red') then $results[self::gx:red, self::gx:yellow]
        else error()
    let $report :=    
        <gx:validationReport domain="{f:getDomainDescriptor($domain)}"
                             countErrors="{count($results/(self::gx:red, self::gx:red))}" 
                             validationTime="{current-dateTime()}"
                             greenfoxDocumentURI="{$gfoxSourceURI}" 
                             greenfoxURI="{$greenfoxURI}"
                             reportType="{$reportType}"
                             reportMediatype="application/xml">{
            for $result in $useResults
            order by 
                switch ($result/local-name(.)) 
                        case 'red' return 1
                        case 'error' return 1
                        case 'yellow' return 2 
                        case 'green' return 3 
                        default return 4,
                $result/(@filePath, @folderPath)[1]                        
            return $result
        }</gx:validationReport>
    return
        $report/f:finalizeReport(.)
};

declare function f:writeValidationReport_whiteTree(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as element() {
    let $gfoxSourceURI := $gfox[1]/@xml:base
    let $greenfoxURI := $gfox[1]/@greenfoxURI
    let $resourceDescriptors :=        
        for $result in $results        
        let $resourceIdentifier := $result/(@filePath, @folderPath)[1]
        let $resourceIdentifierType := $resourceIdentifier/local-name(.)        
        group by $resourceIdentifier
        let $resourceIdentifierAtt :=
            if (not($resourceIdentifier)) then () else
                let $attName := if (i:fox-resource-is-file($resourceIdentifier)) then 'file' else 'folder'
                return
                    attribute {$attName} {$resourceIdentifier}
        let $red := $result/(self::gx:red, self::gx:red)
        let $yellow := $result/self::gx:yellow
        let $green := $result/self::gx:green
        let $other := $result except ($red, $green)
        let $removeAtts :=('filePath', 'folderPath')
        return
            if ($red) then 
                <gx:redResource>{
                    $resourceIdentifierAtt, 
                    $result/self::gx:red/f:removeAtts(., $removeAtts),
                    $result/self::gx:yellow/f:removeAtts(., $removeAtts),
                    $result/self::gx:green/f:removeAtts(., $removeAtts)
                }</gx:redResource>
            else if ($yellow) then 
                <gx:yellowResource>{
                    $resourceIdentifierAtt/self::gx:yellow/f:removeAtts(., $removeAtts), 
                    $result/self::gx:green/f:removeAtts(., $removeAtts)
                }</gx:yellowResource> 
            else if ($green) then 
                <gx:greenResource>{
                    $resourceIdentifierAtt, 
                    $result/f:removeAtts(., $removeAtts)
                }</gx:greenResource>
            else error()
    let $redResources := $resourceDescriptors/self::gx:redResource
    let $yellowResources := $resourceDescriptors/self::gx:yellowResource    
    let $greenResources := $resourceDescriptors/self::gx:greenResource
    let $report :=
        <gx:validationReport domain="{f:getDomainDescriptor($domain) ! i:uriOrPathToNormPath(.)}"
                             countRed="{count($results/self::gx:red)}"
                             countYellow="{count($results/self::gx:yellow)}"
                             countGreen="{count($results/self::gx:green)}"
                             countRedResources="{count($redResources)}"
                             countYellowResources="{count($yellowResources)}"                             
                             countGreenResources="{count($greenResources)}"
                             validationTime="{current-dateTime()}"
                             greenfoxDocumentURI="{$gfoxSourceURI ! i:uriOrPathToNormPath(.)}" 
                             greenfoxURI="{$greenfoxURI}"
                             reportType="{$reportType}"
                             reportMediatype="application/xml">{
            <gx:redResources>{
                attribute count {count($redResources)},
                $redResources
            }</gx:redResources>,
            <gx:yellowResources>{
                attribute count {count($redResources)},
                $yellowResources
            }</gx:yellowResources>,
            <gx:greenResources>{
                attribute count {count($greenResources)},
                $greenResources
            }</gx:greenResources>
        }</gx:validationReport>
    return
        $report/f:finalizeReport(.)
};

(:~
 : Writes a 'redTree' report.
 :
 :)
declare function f:writeValidationReport_redTree(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as element() {
    let $options := map{}
    let $whiteTree := f:writeValidationReport_whiteTree($gfox, $domain, $context, $results, 'redTree', 'xml', $options)        
    let $redTree := f:whiteTreeToRedTree($whiteTree, $options)
    return $redTree
};

(:~
 : Writes a 'constraintCompStat' report.
 :
 :)
declare function f:writeValidationReport_constraintCompStat(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as element() {
    let $options := map{}
    let $whiteTree := f:writeValidationReport_whiteTree($gfox, $domain, $context, $results, 'redTree', 'xml', $options)

    let $fn_listResources := function($resources) {
        for $r in $resources
        let $pathAtt := $r/../(@file, @folder)[1]
        let $elemName := ($pathAtt/local-name(.), 'resource')[1]
        order by if ($elemName eq 'folder') then 2 else 1, $pathAtt 
        return element {$elemName}{$pathAtt/string()}
    }    
    let $entries :=
        for $ccomp in $whiteTree//@constraintComp
        group by $ccname := $ccomp/string()
        let $results := $ccomp/..
        let $green := $results/self::gx:green
        let $red := $results/self::gx:red
        order by $ccname
        return
            <constraintComp name="{$ccname}" countRed="{count($red)}" countGreen="{count($green)}">{
                if (not($red)) then () else
                    <redResources>{$fn_listResources($red)}</redResources>,
                if (not($green)) then () else                    
                    <greenResources>{$fn_listResources($green)}</greenResources>
            }</constraintComp>
    let $report :=
        <constraintComps count="{$entries}">{
            $whiteTree/@domain,
            $whiteTree/@greenfoxDocumentURI,
            $whiteTree/@greenfoxURI,
            $whiteTree/@countRed,
            $whiteTree/@countGreen,
            $whiteTree/@countRedResources,
            $whiteTree/@countGreenResources,
            $entries
        }</constraintComps>
    return $report
};

(:~
 : Writes a 'sum*' report.
 :
 :)
declare function f:writeValidationReport_sum(
                                        $gfox as element(gx:greenfox)+,
                                        $domain as element(gx:domain),                                        
                                        $context as map(xs:string, item()*),                                        
                                        $results as element()*, 
                                        $reportType as xs:string, 
                                        $format as xs:string,
                                        $options as map(*))
        as item() {
    let $options := map{}
    let $ccstat := f:writeValidationReport_constraintCompStat($gfox, $domain, $context, $results, 'redTree', 'xml', $options)
    let $ccomps := $ccstat/*
    
    let $countRed := $ccstat/@countRed/xs:integer(.)
    let $countGreen := $ccstat/@countGreen/xs:integer(.)
    let $countRedResources := $ccstat/@countRedResources/xs:integer(.)
    let $countGreenResources := $ccstat/@countGreenResources/xs:integer(.)
    
    let $redResources := 
        for $r in $ccstat//redResources/(folder, file)
        group by $rname := string($r)
        let $kind := if ($r[1]/self::folder) then 'D' else 'F'
        let $ccomps := $r/../../@name => distinct-values() => sort()
        order by $kind, $rname
        return <resource name="{$rname}" kind="{$kind}" ccomps="{$ccomps}"/>
    let $greenResources :=
        for $r in $ccstat//greenResources/(folder, file)
        group by $rname := string($r)
        let $kind := if ($r[1]/self::folder) then 'D' else 'F'
        let $ccomps := $r/../../@name => distinct-values() => sort()
        order by $kind, $rname
        return <resource name="{$rname}" kind="{$kind}" ccomps="{$ccomps}"/>
            
    let $ccompNameWidth := (('constraint comp', $ccomps/@name) !string-length(.)) => max()
    let $countRedWidth := (('#red', $ccomps/@countRed/string()) ! string-length(.)) => max()
    let $countGreenWidth := (('#green', $ccomps/@countGreen/string()) ! string-length(.)) => max()
    let $hsepChar1 := '-'
    let $hsepChar2 := '-'
    let $hsep1 := tt:repeatChar($hsepChar1, $ccompNameWidth + $countRedWidth + $countGreenWidth + 10)
    let $hsep2 :=
        concat('|', $hsepChar1,
               tt:repeatChar($hsepChar2, $ccompNameWidth), $hsepChar2, '|',
               tt:repeatChar($hsepChar2, $countRedWidth), $hsepChar2, $hsepChar2, '|',
               tt:repeatChar($hsepChar2, $countGreenWidth), $hsepChar2, $hsepChar2)
    let $lines := (
        '',
        'G r e e n f o x    r e p o r t    s u m m a r y',
        '',
        'greenfox: ' || $ccstat/@greenfoxDocumentURI/i:uriOrPathToNormPath(.),
        'domain:   ' || $ccstat/@domain,
        ' ',
        '#red:     ' || $countRed || (if (not($countRed)) then () else concat('   (', $countRedResources, ' resources)')),
        '#green:   ' || $ccstat/@countGreen || (if (not($countGreen)) then () else concat('   (', $countGreenResources, ' resources)')),
        ' ',
        $hsep1,
        '| ' || 
        tt:rpad('Constraint Comp', $ccompNameWidth, ' ') || ' | ' || 
        tt:rpad('#red', $countRedWidth, ' ') || ' | ' || 
        tt:rpad('#green', $countGreenWidth, ' ') || ' |',
        $hsep2,
        for $ccomp in $ccstat/constraintComp
        let $name := $ccomp/@name
        let $countRed := $ccomp/@countRed
        let $countGreen := $ccomp/@countGreen
        return
            concat('| ',
                   tt:rpad($name, $ccompNameWidth, '.'), ' | ', 
                   tt:lpad($countRed, $countRedWidth, ' '), ' | ',
                   tt:lpad($countGreen, $countGreenWidth, ' '),
                   ' |'),
        $hsep1,
        if ($reportType eq 'sum1') then () else (        
            ' ',
            if (empty($redResources)) then () else (
                'Red resources: ',
                $redResources/concat('  ', @kind, ' ', @name, '   (', @ccomps, ')'),
                ' ',        
                if ($reportType eq 'sum2') then () else (
                    if (empty($greenResources)) then () else (
                    'Green resources: ',
                    $greenResources/concat('  ', @kind, ' ', @name, '   (', @ccomps, ')'),
                    ' ')
                )
            )
        )
    )
    let $report := string-join($lines, '&#xA;')
    return $report
};    

(:~
 : Transforms a 'whiteTree' tree report into a 'redTree' report.
 :
 : @param whiteTree a 'whiteTree' report
 : @param options options controlling the report
 : @return the 'redTree' report
 :) 
declare function f:whiteTreeToRedTree($whiteTree as element(gx:validationReport), 
                                      $options as map(*))
        as element(gx:validationReport) {
    f:whiteTreeToRedTreeRC($whiteTree, $options)        
};

(:~
 : Recursive helper function of 'f:whiteTreeToRedTree'.
 :
 : @param n as node from the 'whiteTree' report
 : @param options options controlling the report
 : @return the representation of the node in the 'redTree' report
 :)
declare function f:whiteTreeToRedTreeRC($n as node(), $options as map(*))
        as node()* {
    typeswitch($n)
    case document-node() return
        document {$n ! f:whiteTreeToRedTreeRC(., $options)}
    case element(gx:green) return ()        
    case element(gx:greenResources) return ()

    case element(gx:yellowResources) | element(gx:redResources) return 
        if (not($n//(gx:yellow, gx:red))) then ()
        else
            element {node-name($n)} {
                $n/@* ! f:whiteTreeToRedTreeRC(., $options),
                $n/node() ! f:whiteTreeToRedTreeRC(., $options)            
            }

    case element() return
        element {node-name($n)} {
            $n/@* ! f:whiteTreeToRedTreeRC(., $options),
            $n/node() ! f:whiteTreeToRedTreeRC(., $options)            
        }
    case attribute(reportType) return attribute reportType {'redTree'}        
    default return $n        
};


declare function f:removeAtts($elem as element(),
                             $attName as xs:string+) 
        as element() {
    element {node-name($elem)} {
        $elem/@*[not(local-name(.) = $attName)],
        $elem/node()
    }
};
declare function f:finalizeReport($report as node()) as node() {
    f:finalizeReportRC($report)
};

declare function f:finalizeReportRC($n as node()) as node()? {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:finalizeReportRC(.)}
    case element() return
        let $normName := if (not($n/namespace-uri($n) eq $i:URI_GX)) then node-name($n)
                         else QName($i:URI_GX, string-join(($i:PREFIX_GX, $n/local-name(.)), ':'))
        return
            element {$normName} {
                $n/@* ! f:finalizeReportRC(.),
                in-scope-prefixes($n)[string()] ! namespace {.} {namespace-uri-for-prefix(., $n)},
                $n/node() ! f:finalizeReportRC(.)
            }
    case text() return
        if ($n/../* and not($n/matches(., '\S'))) then () else $n
    default return $n
};

(:~
 : Returns a string describing the domain.
 :)
declare function f:getDomainDescriptor($domain as element(gx:domain))
        as xs:string {
    $domain/@path/replace(., '\\', '/')        
};

