## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::map-key 0
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

namespace eval ::fx::validate::map-key {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil::fx-map-keys
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::map-key::release  {p x} { return }
proc ::fx::validate::map-key::validate {p x} {
    if {$x in [Values $p]} { return $x }
    fail $p MAP-KEY "a mapping key" $x
}

proc ::fx::validate::map-key::default  {p} { return {} }
proc ::fx::validate::map-key::complete {p} {
    complete-enum [Values $p] 0 $x
}

proc ::fx::validate::map-key::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fx-map-keys [$p config @map]]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::map-key 0
return
