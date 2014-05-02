## -*- tcl -*-
# # ## ### ##### ######## ############# ######################
## Save/restore the fx internal state (All fx tables).

# @@ Meta Begin
# Package fx::state 0
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
package require interp

package require fx::mgr::state
package require fx::mgr::enum ; # enumerations
package require fx::seen      ; # notification state

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::state {
    namespace export save restore
    namespace ensemble create

    namespace import ::fx::mgr::state
    rename state mgr
}

# # ## ### ##### ######## ############# ######################

debug level  fx/state
debug prefix fx/state {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::fx::state::save {config} {
    debug.fx/state {}
    variable dumpcmds
    fossil show-repository-location

    # TODO: Some sort of progress callback ?
    set chan [$config @output]
    foreach dump [mgr list] {
	{*}$dump $chan
    }

    close $chan
    return
}

proc ::fx::state::restore {config} {
    debug.fx/state {}
    fossil show-repository-location

    set input [$config @import]
    set data  [read $input]
    $config @import forget

    # TODO: Some sort of progress callback ?
    fossil repository transaction {
	fossil repository eval $data
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::state 0
return
