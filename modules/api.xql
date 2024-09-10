xquery version "3.1";

declare namespace api="http://e-editiones.org/roasted/test-api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace svg="http://www.w3.org/2000/svg";

import module namespace roaster="http://e-editiones.org/roaster";

import module namespace auth="http://e-editiones.org/roaster/auth";
import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace errors="http://e-editiones.org/roaster/errors";

(: import module namespace upload="http://e-editiones.org/roasted/upload" at "upload-api.xqm"; :)
import module namespace upld="https://eldi.soc.cas.cz/api/upload" at "upload.xqm";

(:~
 : list of definition files to use
 :)
declare variable $api:definitions := ("modules/api.json");

(:~
 : This is used as an error-handler in the API definition 
 :)
declare function api:handle-error($error as map(*)) as element(html) {
    <html>
        <body>
            <h1>Error [{$error?code}]</h1>
            <p>{
                if (map:contains($error, "module"))
                then ``[An error occurred in `{$error?module}` at line `{$error?line}`, column `{$error?column}`]``
                else "An error occurred!"
            }</p>
            <h2>Description</h2>
            <p>{$error?description}</p>
        </body>
    </html>
};

declare function api:upload-data ($request as map(*)) {
    let $body :=
        if (
            $request?body instance of array(*) or
            $request?body instance of map(*)
        )
        then ($request?body => serialize(map { "method": "json" }))
        else ($request?body)

    let $stored := xmldb:store("/db/apps/roasted/uploads", $request?parameters?path, $body)
    return roaster:response(201, $stored)
};

declare function api:get-uploaded-data ($request as map(*)) {
    (: xml :)
    if (doc-available("/db/apps/roasted/uploads/" || $request?parameters?path))
    then (
        unparsed-text("/db/apps/roasted/uploads/" || $request?parameters?path)
        => util:base64-encode()
        => response:stream-binary("application/octet-stream", $request?parameters?path)
    )
    (: anything else :)
    else if (util:binary-doc-available("/db/apps/roasted/uploads/" || $request?parameters?path))
    then (
        util:binary-doc("/db/apps/roasted/uploads/" || $request?parameters?path)
        => response:stream-binary("application/octet-stream", $request?parameters?path)
    )
    else (
        error($errors:NOT_FOUND, "document " || $request?parameters?path || " not found", "error details")
    )
};


(: end of route handlers :)

(:~
 : This function "knows" all modules and their functions
 : that are imported here 
 : You can leave it as it is, but it has to be here
 :)
declare function api:lookup ($name as xs:string) {
    function-lookup(xs:QName($name), 1)
};

(: util:declare-option("output:indent", "no"), :)
roaster:route($api:definitions, api:lookup#1)
