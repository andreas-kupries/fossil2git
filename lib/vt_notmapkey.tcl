## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::not-map-key 0
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
    namespace export not-map-key
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: enumerations and items.

namespace eval ::fx::validate::not-map-key {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil::fx-map-keys
    namespace import ::cmdr::validate::common::fail
}

proc ::fx::validate::not-map-key::release  {p x} { return }
proc ::fx::validate::not-map-key::validate {p x} {
    if {$x ni [Values $p]} { return $x }
    fail $p NOT-MAP-KEY "an unused mapping key" $x
}

proc ::fx::validate::not-map-key::default  {p} { return {} }
proc ::fx::validate::not-map-key::complete {p} { return {} }

proc ::fx::validate::not-map-key::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fx-map-keys [$p config @map]]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::not-map-key 0
return
