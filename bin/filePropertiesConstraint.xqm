(:
 : -------------------------------------------------------------------------
 :
 : lastModifiedValidator.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:validateLastModified($filePath as xs:string, $constraint as element(gx:lastModified), $context)
        as element()* {
    let $constraintId := $constraint/@id
    let $constraintLabel := $constraint/@label
    
    let $lt := $constraint/@lt
    let $gt := $constraint/@gt
    let $le := $constraint/@le
    let $ge := $constraint/@ge
    let $eq := $constraint/@eq
    
    let $actValue := file:last-modified($filePath) ! string(.)
    
    let $error := (
        exists($lt) and $actValue >= $lt
        or
        exists($le) and $actValue > $le
        or
        exists($gt) and $actValue <= $gt
        or 
        exists($ge) and $actValue < $ge
        or
        exists($eq) and $actValue != $eq
    )
    where $error
    return
        f:constructError_lastModified($constraint, $actValue)
};

declare function f:validateFileSize($filePath as xs:string, $fileSize as element(gx:fileSize), $context)
        as element()* {
    let $constraintId := $fileSize/@id
    let $constraintLabel := $fileSize/@label
    
    let $lt := $fileSize/@lt
    let $gt := $fileSize/@gt
    let $le := $fileSize/@le
    let $ge := $fileSize/@ge
    let $eq := $fileSize/@eq
    
    let $actValue := file:size($filePath)
    
    let $errors := (
        (: count errors
           ============ :)
        if (empty($lt) or $actValue lt $lt/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $lt, $actValue, ())
        ,
        if (empty($gt) or $actValue gt $gt/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $gt, $actValue, ())
        ,
        if (empty($le) or $actValue le $le/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $le, $actValue, ())
        ,
        if (empty($ge) or $actValue ge $ge/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $ge, $actValue, ())
        ,
        if (empty($eq) or $actValue eq $eq/xs:integer(.)) then () else
            f:constructError_fileSize($constraintId, $constraintLabel, $eq, $actValue, ())
        ,
        ()
    )
    return
        $errors        
};

(:~
 : Constraint component, constraining the file or folder name.
 : The constraint element $fileName can be a <gx:fileName> or a <gx:folderName>.
 :)
declare function f:validateFileName($filePath as xs:string, $fileName as element(), $context)
        as element()* {
    let $constraintId := $fileName/@id
    let $constraintLabel := $fileName/@label
    
    let $eq := $fileName/@eq
    let $like := $fileName/@like
    let $matches := $fileName/@matches
    let $ne := $fileName/@ne
    let $notLike := $fileName/@notLike
    let $notMatches := $fileName/@notMatches
    
    let $actValue := file:name($filePath) ! string(.)
    let $flags := string($fileName/@flags)
    
    let $errors := (
        if (empty($eq) or $actValue eq $eq) then () else
            f:constructError_fileName($constraintId, $constraintLabel, $eq, $actValue, ())
        ,
        if (empty($ne) or $actValue ne $ne) then () else
            f:constructError_fileName($constraintId, $constraintLabel, $ne, $actValue, ())
        ,
        if (empty($matches) or matches($actValue, $matches, $flags)) then () else
            f:constructError_fileName($constraintId, $constraintLabel, $matches, $actValue, ())
        ,
        if (empty($notMatches) or not(matches($actValue, $notMatches, $flags))) then () else
            f:constructError_fileName($constraintId, $constraintLabel, $notMatches, $actValue, ())
        ,
        if (not($like)) then () else
            let $useFlags :=
                if ($flags[string()]) then $flags else 'i'
            let $regex :=
                $like !
                replace(., '\*', '.*') !
                replace(., '\?', '.') !
                concat('^', ., '$')
            return                
                if (matches($actValue, $regex, $flags)) then () else
                    f:constructError_fileName($constraintId, $constraintLabel, $like, $actValue, ())
        ,
        if (not($notLike)) then () else
            let $useFlags :=
                if ($flags[string()]) then $flags else 'i'
            let $regex :=
                $notLike !
                replace(., '\*', '.*') !
                replace(., '\?', '.') !
                concat('^', ., '$')
            return                
                if (not(matches($actValue, $regex, $flags))) then () else
                    f:constructError_fileName($constraintId, $constraintLabel, $notLike, $actValue, ())
        ,        
        ()
    )
    return
        <gx:fileNameErrors count="{count($errors)}">{$errors}</gx:fileNameErrors>
        [$errors]
        
};

declare function f:constructError_lastModified($constraint as element(gx:lastModified),
                                               $actualValue as xs:string) 
        as element(gx:error) {
    let $constraintParams := $constraint/(@lt, @le, @gt, @ge, @eq)          
    let $msg := 
        ($constraint/@msg,
         concat('Last-modified time not ', local-name($constraint), ' check value = ', $constraint))[1]
    return
    
        <gx:error constraintComp="lastModified">{
            $constraint/@id/attribute constraintID {.},
            $constraint/@label/attribute constraintLabel {.},
            $constraintParams,
            attribute actualValue {$actualValue},
            attribute message {$msg}
        }</gx:error>                                                  
};

declare function f:constructError_fileSize($constraintId as attribute()?,
                                           $constraintLabel as attribute()?,
                                           $constraint as attribute(),
                                           $actualValue as xs:integer,
                                           $additionalAtts as attribute()*) 
        as element(gx:error) {
    let $code := 'file-size-not-' || local-name($constraint)
    let $msg := concat('File size not ', local-name($constraint), ' check value = ', $constraint)
    return
    
        <gx:error class="fileSize" code="{$code}">{
            $constraintId,
            $constraintLabel,
            $constraint,
            attribute actValue {$actualValue},
            attribute message {$msg},
            $additionalAtts        
        }</gx:error>                                                  
};

declare function f:constructError_fileName($constraintId as attribute()?,
                                           $constraintLabel as attribute()?,
                                           $constraint as attribute(),
                                           $actualValue as xs:string,
                                           $additionalAtts as attribute()*) 
        as element(gx:error) {
    let $constraintName := local-name($constraint)
    let $code := 'file-name-' || $constraintName
    let $msg := concat('File name ',
                    if ($constraintName eq 'matches') then 'does not match '
                    else concat('not ', $constraintName, ' '),
                    'check value = ', $constraint)
    return
    
        <gx:error class="fileName" code="{$code}">{
            $constraintId,
            $constraintLabel,
            $constraint,
            attribute actValue {$actualValue},
            attribute message {$msg},
            $additionalAtts        
        }</gx:error>                                                  
};

