## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::map 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require fx::fossil
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export map
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: mappings.

namespace eval ::fx::validate::map {
    namespace export release validate default complete table-of
    namespace ensemble create

    namespace import ::fx::fossil::fx-maps
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::map::release  {p x} { return }
proc ::fx::validate::map::validate {p x} {
    set cx [string tolower $x]
    if {$cx in [Values $p]} {
	# Internal representation is the map table.
	return [table-of $cx]
    }
    fail $p MAP "a mapping" $x
}

proc ::fx::validate::map::default {p} {
    # Default is the list of tables of all maps.
    # See 'map export' for the use.
    set t {}
    foreach e [Values $p] {
	lappend t [table-of $e]
    }
    return $t
}

proc ::fx::validate::map::complete {p} {
    complete-map [Values $p] 1 $x
}

proc ::fx::validate::map::table-of {e} {
    return "fx_aku_map_$e"
    # Must match "fx-maps" in fossil.tcl.
}

proc ::fx::validate::map::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fx-maps]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::map 0
return
