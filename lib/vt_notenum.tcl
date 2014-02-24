## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::not-enum 0
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
package require fx::fossil
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export enum
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: enumerations and items.

namespace eval ::fx::validate::not-enum {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil::fx-enums
    namespace import ::cmdr::validate::common::fail
}

proc ::fx::validate::not-enum::release  {p x} { return }
proc ::fx::validate::not-enum::validate {p x} {
    # Note 1: enum names are case-insensitive.
    # Note 2: enum names cannot be multi-line.

    set cx [string tolower $x]
    if {($cx ni [Values $p]) &&
	![string match *\n* $cx]
    } {
	# Internal representation is the enum table.
	return fx_aku_enum_$cx
    }
    fail $p NOT-ENUM "an unused enumeration" $x
}

proc ::fx::validate::not-enum::default  {p} { return {} }
proc ::fx::validate::not-enum::complete {p} { return {} }

proc ::fx::validate::not-enum::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fx-enums]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::not-enum 0
return
