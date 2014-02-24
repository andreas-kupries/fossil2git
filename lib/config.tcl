## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::config 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require fx::table
package require fx::mgr::config

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::config {
    namespace export available list get set unset
    namespace ensemble create

    namespace import ::fx::mgr::config
    namespace import ::fx::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

proc ::fx::config::available {config} {
    variable legal
    puts [join [lsort -dict [dict keys $legal]] \n]
}

proc ::fx::config::list {config} {
    ::set settings [config get-list]

    # TODO: Filter unwanted parts first (dict filter).
    # TODO: order by name, or last-changed.
    # Currently fixed order by name.

    [table t {Setting Global Last-Changed Value} {
	foreach name [lsort -dict [dict keys $settings]] {
	    # Maybe run a dict filter on settings.
	    if {[string match ckout:*     $name]} continue
	    if {[string match peer-*      $name]} continue
	    if {[string match subrepo:*   $name]} continue
	    if {[string match skin:*      $name]} continue
	    if {[string match baseurl:*   $name]} continue
	    if {[string match last-sync-* $name]} continue

	    # Extension variables have their own command heriarchies
	    # to ensure proper use.
	    if {[string match fx-*        $name]} continue

	    lassign [dict get $settings $name] where value time

	    # Force unix EOL conventions.
	    ::set value [string map [::list \r\n \n \r \n] $value]

	    # Reduce multi-line values to their first line.
	    if {[string match *\n* $value]} {
		::set value [lindex [split $value \n] 0]...
	    }
	    # Restrict large values to their first 30 characters.
	    if {[string length $value] > 30} {
		::set value [string range $value 0 29]...
	    }

	    ::set isglobal [expr { ($where eq "G") ? "*" : "" }]
	    if {$mtime ne {}} {
		::set mtime [clock format $mtime]
	    }

	    $t add $name $isglobal $mtime $value
	}
    }] show
    return
}

proc ::fx::config::get {config} {
    puts [config get [$config @setting]]
    return
}

proc ::fx::config::set {config} {
    ::set name   [$config @setting]
    ::set value  [$config @value]
    ::set global [$config @global]

    if {$global} {
	::set r [fossil global-location]
    } else {
	::set r [fossil repository-location]
    }
    # TODO: Reformat r to show relative to cwd

    puts -nonewline "Setting $r (${name}): "

    # This one of two places has to distinguish global/local on get
    # based on the user's choice, instead of the regular heuristics
    # (local, global, default|error).
    if {$global} {
	config set-global $name $value
	set current [config get-global $name]
    } else {
	config set-local $name $value
	set current [config get-local $name]
    }

    puts '$current'
    return
}

proc ::fx::config::unset {config} {
    ::set name   [$config @setting]
    ::set global [$config @global]

    if {$global} {
	::set r [fossil global-location]
    } else {
	::set r [fossil repository-location]
    }
    # TODO: Reformat r to show relative to cwd

    puts -nonewline "Unsetting $r (${name})"

    # This one of two places has to distinguish global/local on get
    # based on the user's choice, instead of the regular heuristics
    # (local, global, default|error).
    if {$global} {
	config unset-global $name $value
    } else {
	config unset-local $name $value
    }

    puts ""
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::config 0
return
