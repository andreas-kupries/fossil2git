## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::user 0
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
package require fx::table
package require fx::fossil
package require textutil::adjust
package require linenoise
package require interp
package require try

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::user {
    namespace export list contact
    namespace ensemble create

    namespace import ::fx::table::do
    namespace import ::fx::fossil
    rename do table
}

# # ## ### ##### ######## ############# ######################

proc ::fx::user::list {config} {
    set map {}
    foreach {login cap info} [fossil user-config] {
	dict set map $login [::list $cap $info]
    }

    [table t {Name Permissions Contact} {
	foreach login [lsort -dict [dict keys $map]] {
	    lassign [dict get $map $login] cap info
	    $t add $login $cap $info
	}
    }] show
    return
}

proc ::fx::user::contact {config} {
    set login   [$config @name]
    set contact [$config @contact]

    # TODO: feedback ...
    # TODO: add colorization and general animated terminal feedback code.
    # TODO: Add --debug support.

    fossil repository transaction {
	fossil repository eval {
	    UPDATE user
	    SET info = :contact
	    WHERE login = :login
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::user 0
return
