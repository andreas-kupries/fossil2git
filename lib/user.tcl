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
package require fx::mailer
package require textutil::adjust
package require linenoise
package require interp
package require try

debug level  fx/user
debug prefix fx/user {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::user {
    namespace export list update-contact push pull sync \
	broadcast
    namespace ensemble create

    namespace import ::fx::table::do
    namespace import ::fx::fossil
    namespace import ::fx::mailer
    rename do table
}

# # ## ### ##### ######## ############# ######################

proc ::fx::user::broadcast {config} {
    debug.fx/user {}

    set content [read [$config @text]]
    $config @text forget

    foreach {login cap info mtime} [fossil user-config] {
	if {![mailer good-address $info]} {
	    puts "Ignoring $login ($info)"
	    continue
	}
	lappend receivers $info
    }
    set receivers [mailer dedup-addresses $receivers]

    puts "Sending to\n* [join $receivers "\n* "]"

    #return;# TODO: dry run
    mailer send \
	[mailer get-config] \
	$receivers \
	$content
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::user::push {config} {
    debug.fx/user {}
    [$config context root] do delegate configuration push user
    return
}

proc ::fx::user::pull {config} {
    debug.fx/user {}
    [$config context root] do delegate configuration pull user
    return
}

proc ::fx::user::sync {config} {
    debug.fx/user {}
    [$config context root] do delegate configuration sync user
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::user::list {config} {
    debug.fx/user {}

    set map {}
    foreach {login cap info mtime} [fossil user-config] {
	dict set map $login [::list $cap $info $mtime]
    }

    #array set uu $map ; parray uu ; unset uu

    [table t {Name Permissions Contact Changed Notes} {
	foreach login [lsort -dict [dict keys $map]] {
	    lassign [dict get $map $login] cap info mtime
	    set mtime [expr {($mtime ne {})
			     ? [clock format $mtime]
			     : ""}]
	    set notes [expr {[mailer good-address $info]
			     ? ""
			     : "** No Email **"}]
	    $t add $login $cap $info $mtime $notes
	}
    }] show
    return
}

proc ::fx::user::update-contact {config} {
    debug.fx/user {}

    set login   [$config @user]
    set contact [$config @contact]
    set now     [clock seconds]

    # TODO: feedback ...
    # TODO: add colorization and general animated terminal feedback code.
    # TODO: Add --debug support.

    puts -nonewline "Updating \"$login\" to \"$contact\""
    flush stdout

    fossil repository transaction {
	fossil repository eval {
	    UPDATE user
	    SET info  = :contact,
	        mtime = :now
	    WHERE login = :login
	}
    }

    puts OK
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::user 0
return
