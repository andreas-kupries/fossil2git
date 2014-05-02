## -*- tcl -*-
# # ## ### ##### ######## ############# ######################
## Save/restore the fx internal state (All fx tables).

# @@ Meta Begin
# Package fx::mgr::state 0
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
package require debug
package require debug::caller

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::mgr::state {
    namespace export register list
    namespace ensemble create

    # List of commands to run to dump all tables managed by fx. The
    # relevant modules claim their interest via 'register'.
    variable dumpcmds {}
}

# # ## ### ##### ######## ############# ######################

debug level  fx/mgr/state
debug prefix fx/mgr/state {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::fx::mgr::state::register {cmd} {
    variable dumpcmds
    debug.fx/mgr/state {}
    lappend dumpcmds $cmd
    return
}

proc ::fx::mgr::state::list {} {
    variable dumpcmds
    debug.fx/mgr/state {==> $dumpcmds}
    return  $dumpcmds
}

# # ## ### ##### ######## ############# ######################
package provide fx::mgr::state 0
return
