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
package require cmdr::color
package require cmdr::ask

package require fx::fossil
package require fx::validate::uuid

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::shun {
    namespace export list add remove

    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
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
	    set flag [expr { [uuid ok $uuid] ? "yes" : "   no" }]
	    $t add $flag $uuid [clock format $mtime] $scom
	}
    }] show
    return
}

proc ::fx::shun::add {config} {
    debug.fx/shun {}
    fossil show-repository-location

    set ulist [DropShunned [$config @uuid]]
    if {![llength $ulist]} {
	puts [color note "Nothing to shun"]
	return
    }

    [table t {{UUID to shun}} {
	foreach u $ulist { $t add $u }
    }] show

    set confirmed [ask yn "Please confirm that you wish to shun the [llength $ulist] uuids above" no]
    if {!$confirmed} {
	puts [color note "You have canceled the operation.\nThank you and good bye."]
	return
    }

    puts -nonewline "Shunning ... "
    flush stdout

    set now [clock seconds]
    fossil repository transaction {
	foreach u $ulist {
	    fossil repository eval {
		INSERT
		INTO shun 
		VALUES (:u, :now, NULL)
	    }
	}
    }

    puts [color good OK]
    return
}

proc ::fx::shun::remove {config} {
    debug.fx/shun {}
    fossil show-repository-location

    set ulist [DropNotShunned [$config @uuid]]
    if {![llength $ulist]} {
	puts [color note "Nothing to accept"]
	return
    }

    [table t {{UUID to accept}} {
	foreach u $ulist { $t add $u }
    }] show

    set confirmed [ask yn "Please confirm that you wish to (re)accept the [llength $ulist] uuids above." no]
    if {!$confirmed} {
	puts [color note "You have canceled the operation.\nThank you and good bye."]
	return
    }

    puts -nonewline "Accepting ... "
    flush stdout

    set now [clock seconds]
    fossil repository transaction {
	foreach u $ulist {
	    fossil repository eval {
		DELETE FROM shun
		WHERE uuid = :u
	    }
	}
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::shun::DropShunned {ulist} {
    set shunned [List]
    set r {}
    foreach u $ulist {
	if {$u in $shunned} {
	    puts "${u}: [color warning {Already shunned}]"
	    continue
	}
	lappend r $u
    }
    return $r
}

proc ::fx::shun::DropNotShunned {ulist} {
    set shunned [List]
    set r {}
    foreach u $ulist {
	if {$u ni $shunned} {
	    puts "${u}: [color warning {Not shunned}]"
	    continue
	}
	lappend r $u
    }
    return $r
}

proc ::fx::shun::List {} {
    return [fossil repository eval {
	SELECT uuid
	FROM   shun
    }]
}

# # ## ### ##### ######## ############# ######################
package provide fx::shun 0
return
