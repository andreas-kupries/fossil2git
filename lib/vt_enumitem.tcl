## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::enum-item 0
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

namespace eval ::fx::validate::enum-item {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil::fx-enum-items
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::enum-item::release  {p x} { return }
proc ::fx::validate::enum-item::validate {p x} {
    if {$x in [Values $p]} { return $x }
    fail $p ENUM-ITEM "an enumeration item" $x
}

proc ::fx::validate::enum-item::default  {p} { return {} }
proc ::fx::validate::enum-item::complete {p} {
    complete-enum [Values $p] 0 $x
}

proc ::fx::validate::enum-item::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fx-enum-items [$p config @enum]]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::enum-item 0
return
