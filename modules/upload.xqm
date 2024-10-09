xquery version "3.1";

module namespace upld="https://eldi.soc.cas.cz/api/upload";


import module namespace roaster="http://e-editiones.org/roaster";
import module namespace unzip="http://joewiz.org/ns/xquery/unzip" at "unzip.xql";
import module namespace config = "http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace idx = "http://teilex0/ns/xquery/index" at "report.xql";
import module namespace console="http://exist-db.org/xquery/console";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace compression = "http://exist-db.org/xquery/compression";


declare default collation "?lang=cs";


declare namespace map = "http://www.w3.org/2005/xpath-functions/map";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace query="http://www.tei-c.org/tei-simple/query";

declare variable $upld:NOT_FOUND := xs:QName("errors:NOT_FOUND_404");

declare variable $upld:channel := "upload";

declare option exist:serialize "method=xml media-type=application/xml";

declare variable $upld:QUERY_OPTIONS := map {
    "leading-wildcard": "yes",
    "filter-rewrite": "yes"
};

declare function upld:download-collection($request as map(*)) {
    let $start-time as xs:time := util:system-time()
    let $name := upld:get-collection($request)
    let $main-collection := tokenize($name, "/")[last()] => lower-case()
    let $collectionPath := ($config:data-root || "/" || $name) => replace("//", "/")
    (: return
    error($errors:NOT_FOUND, "Collection " || $collectionPath || " not found; " || xmldb:collection-available($collectionPath) ) :)
    
    return if(xmldb:collection-available($collectionPath)) then
        let $zip := compression:zip(xs:anyURI($collectionPath), true())
        return response:stream-binary($zip, "application/zip") (: roaster:response(200, "application/zip", $zip) :)
     else
        error($errors:NOT_FOUND, "Collection " || $collectionPath || " not found")
    
};
declare function upld:download-document($request as map(*)) {
    let $start-time as xs:time := util:system-time()
    let $name := upld:get-collection($request)
    let $id := xmldb:decode($request?parameters?id)
    let $main-collection := tokenize($name, "/")[last()] => lower-case()
    let $collectionPath := $config:data-root || "/" || $name
    let $document-uri := $collectionPath || "/" || $id
    return if(doc-available($document-uri)) then
      roaster:response(200, "application/xml", doc($document-uri))
     else
        error($errors:NOT_FOUND, "Document " || $id || " in the collection " || $collectionPath || " not found")
};

declare function upld:upload($request as map(*)) {
    let $start-time as xs:time := util:system-time()
    let $root := upld:get-collection($request)
    return
    try {
        let $name := request:get-uploaded-file-name("file")
        let $data := request:get-uploaded-file-data("file")
        let $upload-result := upld:upload($root, $name, $data)
        let $end-time as xs:time := util:system-time()
    (: let $log := console:log($upld:channel, "$name: " || $name) :)
    return
        (: roaster:response(201, map { 
                "uploaded": $upload:download-path || $file-name }) :)
        (: array { upld:upload($request?parameters?collection, $name, $data) } :)
        roaster:response(201,
        <result file-name="{$name}" start="{$start-time}" end="{$end-time}" duration="{seconds-from-duration($end-time - $start-time)}s">
            {$upload-result}
        </result>
        )
    }
    catch * {
        let $end-time as xs:time := util:system-time()
        (: roaster:response(400, map { "error": $err:description })         :)
        return
        roaster:response(400, <error start="{$start-time}" end="{$end-time}" duration="{seconds-from-duration($end-time - $start-time)}s">{ $err:description }</error>)
    }
        
};


declare %private function upld:upload($root, $paths, $payloads) {
    let $collectionPath := if(starts-with($root, 'db/system/config' || $config:data-root)) then "/" || $root else $config:data-root || "/" || $root
    let $result := for-each-pair($paths, $payloads, function($path, $data) {
        let $paths :=
            let $log := console:log($upld:channel, "$collectionPath: " || $collectionPath)
            return
                if (xmldb:collection-available($collectionPath)) then
                
                    if (ends-with($path, ".zip")) then
                        let $stored := xmldb:store($collectionPath, xmldb:encode($path), $data)
                        (: let $log := console:log($upld:channel, "$stored: " || $stored) :)
                        let $unzip := unzip:unzip($stored, true())
                        (: let $log := console:log($upld:channel, "$unzip: " || string-join($unzip//entry/@path, '; ')) :)
                        (: return $unzip//entry/@path :)
                        return $unzip
                    else if (ends-with($path, ".xml") or ends-with($path, ".xconf")) then
                        let $stored := xmldb:store($collectionPath, xmldb:encode($path), $data)
                        return <entries target-collection="{$collectionPath}" count-stored="{if($stored) then 1 else 0}" count-unable-to-store="{if($stored) then 0 else 1}" deleted="false">
                            <entry path="{$collectionPath}" file="{$path}" />
                         </entries>
                    else
                    ()
                else
                    error($upld:NOT_FOUND, "Collection not found: " || $collectionPath)
        return
            $paths
            (:
            for $path in $paths 
                let $size := xmldb:size($collectionPath, $path)
                let $log := console:log($upld:channel, "$size: " || $path || " = " || $size)
            return
                map {
                    "name": $path,
                    "path": substring-after($path, $config:data-root || "/" || $root),
                    "type": xmldb:get-mime-type($path),
                    "size": xmldb:size($collectionPath, $path)
                }
                :)
    })
    return $result
};

declare function upld:clean($request as map(*)) {
    try {
       let $name := upld:get-collection($request)
        let $main-collection := tokenize($name, "/")[last()] => lower-case()
        let $collectionPath := $config:data-root || "/" || $name
        return if($main-collection = ("dictionaries", "about", "feedback", "metadata")) then
            roaster:response(400,
            <result>{concat("Cannot delete main collection '", $main-collection, "'.")}</result>
            )
        else if($collectionPath = $config:data-root || "/") then
            roaster:response(400,
            <result>{concat("Cannot delete main collection '", $collectionPath, "'.")}</result>
            )
        else
            
            let $result := xmldb:remove($collectionPath)
            return roaster:response(200,
                <result>Collection {$name} deleted.</result>)

    }
    catch * {
        (: roaster:response(400, map { "error": $err:description })         :)
        roaster:response(400, <error>{ $err:description }</error>)
    }

};

declare function upld:report($request as map(*)) { 
    let $name := $request?parameters?collection
    let $count := $request?parameters?count
    (: return idx:get-collection-statistics() :)
    return idx:get-index-statistics($count)
};

declare function upld:autocomplete($request as map(*)) {
    let $max-items := 30
    let $index := "lucene-index"
    let $f := function($key, $count) {$key}
    let $lower-case-q := lower-case($request?parameters?query)
    let $field := lower-case($request?parameters?field)
    let $name := $request?parameters?collection

    let $items := collection($config:data-root || "/" || $name)/ft:index-keys-for-field($field, $lower-case-q,
                    $f, $max-items)
    let $items:= sort($items)
    return $items
};

declare function upld:query($request as map(*)) { 
    let $collection-name := $request?parameters?collection
    let $query := json-to-xml($request?parameters?query)
    let $per-page := $request?parameters?per-page
    let $start := $request?parameters?start

    let $starts-with := $query//fn:string[@key='startsWith']
    let $options := upld:options("sort-key", ())

    let $collection := collection($config:data-root || "/" || $collection-name)
    let $hitsAll := $collection//tei:entry[ft:query(., $starts-with || "*", $options)]
    let $hits := subsequence($hitsAll, $start, $per-page)
    let $map-to-xml := function($key, $value) { <item value="{$key}" count="{$value}" /> }

    let $countAll := count($hitsAll)
    let $count := count($hits)

    let $dimensions := ("aspect", "attestation", "attestation-author", 
    "attestation-hierarchy", "attestation-title", "attitude", 
    "case", "cross-reference-type", 
    "dictionary", "domain", "domain-contemporary", "domain-hierarchy", 
    "entry-author", "entry-phase", "entry-type", "etymology-type", 
    "frequency", "gender", "geographic", "government", 
    "hint", "meaningType", "metamark", "mood", 
    "normativity", "number", "objectLanguage", 
    "person", "polysemy", "pos", "reference-type", 
    "socioCultural", "targetLanguage", "tense", "textType", "time",
     "voice")
    
    let $facets := for $dimension in $dimensions 
        let $map := ft:facets($hits, $dimension, ())
        return <facet dimension="{$dimension}">{map:for-each($map, $map-to-xml)}</facet>
    
    let $header :=(
    response:set-header("pb-total", xs:string($countAll)),
    response:set-header("pb-start", xs:string($start))
    )
    return
    <collection name="{$collection-name}" all="{$countAll}" start="{$start}" shown="{$count}">
    <entries>{$hits}</entries>
    <facets>{$facets}</facets>
    </collection>
};

declare function upld:options($sortBy as xs:string*, $field as xs:string?) {
    map:merge((
        $upld:QUERY_OPTIONS,
        map {
            "facets":
                map:merge((
                    for $param in request:get-parameter-names()[matches(., $config:query-facet-pattern)]
                    let $dimension := replace($param, $config:query-facet-pattern , '$1')
                    return
                        map {
                            $dimension: request:get-parameter($param, ())
                        }
                ))
        },
        if ($sortBy) then
            map { "fields": ($sortBy, $config:default-fields, $field) }
        else
            map { "fields": ($config:default-fields, $field) }
    ))
};

declare function upld:permission($request as map(*)) {
    let $collection := upld:get-collection($request)
    let $collectionPath := $config:data-root || "/" || $collection
    return if (xmldb:collection-available($collectionPath)) then
        let $file-permission := "rw-rw-r--"
        let $change := for $document in collection($collectionPath)
            (: xs:anyURI($collectionPath || "/" || $filename) :)
            return sm:chmod(base-uri($document), $file-permission)
        return roaster:response(204,
                <result>Permission in collection {$collection} applied.</result>)
    else
        error($upld:NOT_FOUND, "Collection not found: " || $collectionPath)
};

declare %private function upld:get-collection($request as map(*)) {
    let $collection := xmldb:decode-uri($request?parameters?collection)
    let $collection := if(ends-with($config:data-root, "/" || $collection))
        then "" 
        else if(starts-with($collection, 'data/')) 
            then substring-after($collection, 'data/')
            else $collection
    return $collection
};

(:
let $collection := request:get-parameter("collection", ())
let $pathParam := request:get-parameter("path", ())
let $name := request:get-uploaded-file-name("file[]")
let $path := ($pathParam, $name)[1]
let $data := request:get-uploaded-file-data("file[]")

return
    try {
        upld:upload($collection, $path, $data)
    } catch * {
        map {
            "name": $name,
            "error": $err:description
        }
    }
:)