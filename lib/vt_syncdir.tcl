## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::sync-dir 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export sync-dir
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration sync-dirs

namespace eval ::fx::validate::sync-dir {
    namespace export release validate default complete legal
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::sync-dir::release  {p x} { return }
proc ::fx::validate::sync-dir::validate {p x} {
    set cx [string tolower $x]
    if {$cx in [legal]} { return $cx }
    fail $p SYNC-DIR "a sync direction" $x
}

proc ::fx::validate::sync-dir::default  {p} { return all }
proc ::fx::validate::sync-dir::complete {p} {
    complete-enum [legal] 1 $x
}

# # ## ### ##### ######## ############# ######################

proc ::fx::validate::sync-dir::legal {} {
    return {pull push sync}
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::sync-dir 0
return
