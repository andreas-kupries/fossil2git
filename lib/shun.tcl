## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::shun 0
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

package require fx::color
package require fx::fossil
package require fx::validate::uuid

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::shun {
    namespace export list add remove

    namespace ensemble create

    namespace import ::fx::color
    namespace import ::fx::fossil
    namespace import ::fx::validate::uuid

    namespace import ::fx::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  fx/shun
debug prefix fx/shun {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::fx::shun::list {config} {
    debug.fx/shun {}
    fossil show-repository-location
    [table t {Content UUID Added SCOM} {
	fossil repository eval {
	    SELECT uuid, mtime, scom
	    FROM shun
	} {
	    # mtime unit is [epoch].
	    set flag [expr { [uuid ok $uuid] ? "yes" : "" }]
	    $t add $flag $uuid [clock format $mtime] $scom
	}
    }] show
    return
}

proc ::fx::shun::add {config} {
    debug.fx/shun {}
    fossil show-repository-location
    error "not-yet-implemented"

    # TODO: filter out already shunned
    # TODO: abort if nothing left
    # TODO: show remaining uuids, and
    # TODO: interactively confirm to shun them.
    # TODO: add to shun, if confirmed.
    return
}

proc ::fx::shun::remove {config} {
    debug.fx/shun {}
    fossil show-repository-location
    error "not-yet-implemented"

    # TODO: filter out those not shunned
    # TODO: abort if nothing left
    # TODO: show remaining uuids, and
    # TODO: interactively confirm to accept them.
    # TODO: remove from shun, if confirmed.
    return
}

# # ## ### ##### ######## ############# ######################



# # ## ### ##### ######## ############# ######################
package provide fx::shun 0
return
