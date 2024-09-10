xquery version "3.1";

declare namespace idx="http://teipublisher.com/index";

declare namespace q = "http://teilex0/ns/xquery/query"; 
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace functx = "http://www.functx.com";
declare namespace exist = "http://exist.sourceforge.net/NS/exist";


declare variable $q:collection external := "/db/apps/lediir-data/data/dictionaries";
declare variable $q:query external := "síla";
declare variable $q:field external := "equivalent";
declare variable $q:max-items external := 20;
declare variable $q:field-boost external := 1;


declare variable $idx:parentheses-todo := "remove"; (: "remove" | "move" | "keep" :)
declare variable $idx:payload-todo := true();

declare variable $idx:frequency-boost := map {
    'A' : 50,
    'B' : 40,
    'C' : 30,
    'D' : 20,
    'E' : 10,
    'R' : 1,
    'X' : 1
 };

declare variable $idx:sense-boost := map {
  1 : 5,
  2 : 3,
  3 : 1
 };

 declare variable $idx:equivalent-boost := map {
  1 : 5,
  2 : 3,
  3 : 1
 };

declare variable $idx:sense-uniqueness-max := 5;
 
declare function functx:add-attributes
        ( $elements as element()*,
        $attrNames as xs:QName*,
        $attrValues as xs:anyAtomicType* ) as element()* {
                for $element in $elements
                        return element { node-name($element)}
                { for $attrName at $seq in $attrNames
                        return if ($element/@*[node-name(.) = $attrName])
                                then ()
                                else attribute {$attrName}
                        {$attrValues[$seq]},
                        $element/@*,
                        $element/node() 
                }
};


let $maps-to-text := function($k, $v) {concat($k, ' ~ ', $v)}

let $text-in-parentheses := switch($idx:parentheses-todo)
        case "remove"
               return "odstraněno"
        case "move"
               return "přesunuto na konec"
        default
               return "beze změn"

let $preprocessing := if($idx:payload-todo) then "přihlížet k pozici ve významu" || "|" else "bez ohledu na pozici ve významu" || "|"
let $preprocessing := $preprocessing || "text v závorkách (kontextové poznámky): " ||  $text-in-parentheses || "|"

let $preprocessing := $preprocessing || "posílení frekvence: " || string-join(map:for-each($idx:frequency-boost, $maps-to-text), " ↣ ") || "|"
let $preprocessing := $preprocessing || "posílení čísla významu: " || string-join(map:for-each($idx:sense-boost, $maps-to-text), " ↣ ") || "|"
let $preprocessing := $preprocessing || "jedinečnost významu: " || "od 1 do " || $idx:sense-uniqueness-max || "|"
let $preprocessing := $preprocessing || "posílení pozice ekvivalentu: " || string-join(map:for-each($idx:equivalent-boost, $maps-to-text), " ↣ ") || "|"
let $preprocessing := $preprocessing || "řazení podle skóre sestupně, v případě shody podle abecedy vzestupně"

let $query := <exist:query field="{$q:field}" query="{$q:query}" 
        boost="{$q:field-boost}" sort="score * corpusFrequencyBoost * sensePositionBoost * senseUniquenessBoost * equivalentPositionBoost" 
        preprocessing="{$preprocessing}" />


let $items := collection($q:collection)//tei:entry[tei:sense/tei:def/tei:seg[
        ft:query(
                ., $q:field || ":" || $q:query || "^" || $q:field-boost, 
                map { "leading-wildcard": "yes", "filter-rewrite": "yes", 
                "fields": ("equivalentPositionBoost", "corpusFrequencyBoost", 
                "sensePositionBoost", "senseUniquenessBoost", "sortKey")  }
        )]]
let $items := for $item in $items 
let $sortKey := ft:field($item, "sortKey")
let $equivalentPositionBoost := ft:field($item, "equivalentPositionBoost", "xs:double")
let $corpusFrequencyBoost := ft:field($item, "corpusFrequencyBoost", "xs:double")
let $sensePositionBoost := ft:field($item, "sensePositionBoost", "xs:double")
let $senseUniquenessBoost := ft:field($item, "senseUniquenessBoost", "xs:double")
let $score := ft:score($item) * $equivalentPositionBoost * $corpusFrequencyBoost
        * $sensePositionBoost * $senseUniquenessBoost
order by $score  descending, $sortKey ascending
return  (<exist:score value="{$score}" 
                score="{ft:score($item)}" 
                equivalentPositionBoost = "{$equivalentPositionBoost}"
                corpusFrequencyBoost="{$corpusFrequencyBoost}" 
                sensePositionBoost="{$sensePositionBoost}" 
                senseUniquenessBoost="{$senseUniquenessBoost}" 
                ref="#{$item/@xml:id}" />, 
        util:expand($item)
)

return <body xmlns="http://www.tei-c.org/ns/1.0" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:exist="http://exist.sourceforge.net/NS/exist">{($query, $items)}</body>