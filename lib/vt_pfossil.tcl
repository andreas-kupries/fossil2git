## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::peer-fossil 0
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
package require fx::mgr::map
package require fx::peer

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export peer-fossil
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: Fossil repository peers

namespace eval ::fx::validate::peer-fossil {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::mgr::map
    namespace import ::fx::peer
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::peer-fossil::release  {p x} { return }
proc ::fx::validate::peer-fossil::validate {p x} {
    if {$x in [Values $p]} { return $x }
    fail $p PEER-FOSSIL "a fossil peer" $x
}

proc ::fx::validate::peer-fossil::default  {p} { return {} }
proc ::fx::validate::peer-fossil::complete {p} {
    complete-enum [Values $p] 0 $x
}

proc ::fx::validate::peer-fossil::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    peer init
    return [map keys fx@peer@fossil]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::peer-fossil 0
return
