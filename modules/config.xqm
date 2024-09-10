xquery version "3.1";

(:~
 : A set of helper functions to access the application context from
 : within a module.
 :)
module namespace config="http://www.tei-c.org/tei-simple/config";
import module namespace system = "http://exist-db.org/xquery/system";

(:
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root :=
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

(:~
 : The root of the collection hierarchy containing data.
 :)
declare variable $config:data-root := $config:app-root || "/data";

declare variable $config:query-facet-pattern := ((), "^facet-(.*)$$")[1];

declare function config:facet-name($dimension as xs:string) {
    translate($config:query-facet-pattern, "^\$$", "") => replace("\(\.\*\)", $dimension)
};

declare variable $config:default-fields := ("lemma");

