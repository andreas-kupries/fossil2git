## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::enum 0
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
    namespace export enum
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: enumerations and items.

namespace eval ::fx::validate::enum {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil::fx-enums
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::enum::release  {p x} { return }
proc ::fx::validate::enum::validate {p x} {
    set cx [string tolower $x]
    if {$cx in [Values $p]} {
	# Internal representation is the enum table.
	return fx_aku_enum_$cx
    }
    fail $p ENUM "an enumeration" $x
}

proc ::fx::validate::enum::default  {p} {
    # Default is the tables of all enums.
    # See 'enum export' for the use.
    set t {}
    foreach e [Values $p] {
	lappend t fx_aku_enum_$e
    }
    return $t
}

proc ::fx::validate::enum::complete {p} {
    complete-enum [Values $p] 1 $x
}

proc ::fx::validate::enum::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fx-enums]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::enum 0
return
