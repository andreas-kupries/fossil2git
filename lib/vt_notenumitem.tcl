## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::not-enum-item 0
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

namespace eval ::fx::validate::not-enum-item {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil::fx-enum-items
    namespace import ::cmdr::validate::common::fail
}

proc ::fx::validate::not-enum-item::release  {p x} { return }
proc ::fx::validate::not-enum-item::validate {p x} {
    if {$x ni [Values $p]} { return $x }
    fail $p NOT-ENUM-ITEM "an unused enumeration item" $x
}

proc ::fx::validate::not-enum-item::default  {p} { return {} }
proc ::fx::validate::not-enum-item::complete {p} { return {} }

proc ::fx::validate::not-enum-item::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fx-enum-items [$p config @enum]]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::not-enum-item 0
return
