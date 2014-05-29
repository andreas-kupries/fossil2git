## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::not-peer-fossil 0
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
    namespace export not-peer-fossil
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: Fossil repository not-peers

namespace eval ::fx::validate::not-peer-fossil {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::mgr::map
    namespace import ::fx::peer
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::not-peer-fossil::release  {p x} { return }
proc ::fx::validate::not-peer-fossil::validate {p x} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    peer init

    # Can be any url (may exist!), except git peers. We allow the url
    # to exist to be able to handle the possibility of incrementally
    # adding areas and directions for a peer.

    if {$x ni [map keys fx@peer@git]
    } { return $x }
    fail $p NOT-PEER-FOSSIL "a possible fossil peer" $x
}

proc ::fx::validate::not-peer-fossil::default  {p} { return {} }
proc ::fx::validate::not-peer-fossil::complete {p} { return {} }

# # ## ### ##### ######## ############# ######################
package provide fx::validate::not-peer-fossil 0
return
