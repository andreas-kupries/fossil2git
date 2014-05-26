## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::not-map 0
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
    namespace export not-map
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: mappings.

namespace eval ::fx::validate::not-map {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil::fx-maps
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::fail-known-thing

    variable illegal "\n!@#$%^&*()={}\"';<>?~`\[\[.\].\]"
    variable pattern "\[$illegal\]"
}

proc ::fx::validate::not-map::release  {p x} { return }
proc ::fx::validate::not-map::validate {p x} {
    variable pattern
    # Note 1: map names are case-insensitive.
    # Note 2: map names cannot be multi-line,
    #         nor contain many special characters.

    set cx [string tolower $x]

    if {[regexp $pattern $cx]} {
	# Lexical failure.
	variable illegal
	fail $p NOT-MAP "a mapping name" $x " (Not allowed: [string map [list \n \\n] $illegal])"
    }

    if {$cx in [Values $p]} {
	fail-known-thing $p NOT-MAP "mapping" $x
    }

    # Internal representation is the map table.
    # Must match "fx-maps" in fossil.tcl
    return fx_aku_map_$cx
}

proc ::fx::validate::not-map::default  {p} { return {} }
proc ::fx::validate::not-map::complete {p} { return {} }

proc ::fx::validate::not-map::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fx-maps]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::not-map 0
return
