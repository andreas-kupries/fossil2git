## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::enum 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require fx::table
package require textutil::adjust
package require linenoise
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::enum {
    namespace export list create delete export import add remove change \
	known notknown
    namespace ensemble create

    namespace import ::fx::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: enumerations and items.

namespace eval ::fx::enum::known {
    namespace export release validate default complete \
	Values ValuesDB
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::enum::known::release  {p x} { return }
proc ::fx::enum::known::validate {p x} {
    set cx [string tolower $x]
    if {$cx in [Values $p]} { return $cx }
    fail $p KNOWN "an enumeration" $x
}

proc ::fx::enum::known::default  {p} { return {} }
proc ::fx::enum::known::complete {p} {
    complete-enum list [Values $p] $x
}

proc ::fx::enum::known::Values {p} {
    return [ValuesDB [$p config @repository-db]]
}

proc ::fx::enum::known::ValuesDB {db} {
    set enums {}
    $db eval {
	SELECT name
	FROM sqlite_master
	WHERE type = 'table'
	AND   name LIKE 'fx_aku_enum_%'
	;
    } {
	regsub {^fx_aku_enum_} $name {} name
	lappend enums [string tolower $name]
    }
    return $enums
}

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::enum::notknown {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::enum::known::Values
    namespace import ::cmdr::validate::common::fail
}

proc ::fx::enum::notknown::default  {p}   { return {} }
proc ::fx::enum::notknown::complete {p}   { return {} }
proc ::fx::enum::notknown::release  {p x} { return }
proc ::fx::enum::notknown::validate {p x} {
    set cx [string tolower $x]
    if {$cx ni [Values $p]} { return $cx }
    fail $p NOTKNOWN "an unused enumeration" $x
}

# # ## ### ##### ######## ############# ######################

proc ::fx::enum::MaxL {words} {
    ::set max 0 
    foreach w $words {
	set l [string length $w]
	if {$l <= $max} continue
	::set max $l
    }
    return $max
}

proc ::fx::enum::list {config} {
    [table t {Name Elements} {
	::set db    [$config @repository-db]
	::set enums [known::ValuesDB $db]

	set w [MaxL $enums]
	set w [expr {[linenoise columns] - $w - 7}]

	foreach e $enums {
	    set items [join [$db eval [subst {
		SELECT item
		FROM   fx_aku_enum_$e
		ORDER BY item
	    }]] {, }]

	    set items [textutil::adjust::adjust $items -length $w]
	    $t add $e $items
	}
    }] show
}

proc ::fx::enum::create {config} {
    ::set db   [$config @repository-db]
    ::set name [$config @newenum]

    $db eval [subst {
	CREATE TABLE fx_aku_enum_$name (
	    id   INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    item TEXT    UNIQUE
	);
    }]

    foreach item [lsort -unique [$config @values]] {
	$db eval [subst {
	    INSERT INTO fx_aku_enum_$name VALUES (NULL, :item);
	}]
    }
    return
}

proc ::fx::enum::delete {config} {
    ::set db   [$config @repository-db]
    ::set name [$config @enum]

    $db eval [subst {
	DROP TABLE fx_aku_enum_$name
    }]
    return
}

proc ::fx::enum::export {config} {
    ::set db   [$config @repository-db]
    ::set name [$config @enum]
    ::set chan [$config @export]

    $db eval [subst {
	SELECT item
	FROM   fx_aku_enum_$name
	ORDER BY item
	;
    }] {
	# TODO:     Define a better format which allows multi-line values.
	# TODO ALT: Disallow multi-line enum values => validation.
	puts $chan $item
    }
    return
}

proc ::fx::enum::import {config} {
    ::set db [$config @repository-db]
    return
}

proc ::fx::enum::add {config} {
    ::set db [$config @repository-db]
    return
}

proc ::fx::enum::remove {config} {
    ::set db [$config @repository-db]
    return
}

proc ::fx::enum::change {config} {
    ::set db [$config @repository-db]
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::enum 0
return
