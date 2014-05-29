## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::peer-git 0
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
    namespace export peer-git
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: Fossil repository peers

namespace eval ::fx::validate::peer-git {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::mgr::map
    namespace import ::fx::peer
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::peer-git::release  {p x} { return }
proc ::fx::validate::peer-git::validate {p x} {
    if {$x in [Values $p]} { return $x }
    fail $p PEER-GIT "a git peer" $x
}

proc ::fx::validate::peer-git::default  {p} { return {} }
proc ::fx::validate::peer-git::complete {p} {
    complete-enum [Values $p] 0 $x
}

proc ::fx::validate::peer-git::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    peer init
    return [map keys fx@peer@git]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::peer-git 0
return
