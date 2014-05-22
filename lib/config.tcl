## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::config 0
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
package require fx::fossil
package require fx::mgr::config
package require fx::table
package require fx::validate::setting

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::config {
    namespace export available list get set unset
    namespace ensemble create

    namespace import ::fx::fossil
    namespace import ::fx::mgr::config
    namespace import ::fx::validate::setting

    namespace import ::fx::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

proc ::fx::config::available {config} {
    variable legal
    puts [join [lsort -dict [dict keys [setting legal]]] \n]
}

proc ::fx::config::list {config} {
    ::set settings [config get-list]

    # TODO: Filter unwanted parts first (dict filter).
    # TODO: order by name, or last-changed.
    # Currently fixed order by name.

    fossil show-repository-location
    [table t {Setting Value Last-Changed} {
	foreach name [lsort -dict [dict keys $settings]] {
	    # Maybe run a dict filter on settings.
	    if {[string match ckout:*     $name]} continue
	    if {[string match peer-*      $name]} continue
	    if {[string match subrepo:*   $name]} continue
	    if {[string match skin:*      $name]} continue
	    if {[string match baseurl:*   $name]} continue
	    if {[string match last-sync-* $name]} continue

	    # Extension variables have their own command heirarchies
	    # to ensure proper use.
	    if {[string match fx-*        $name]} continue

	    lassign [dict get $settings $name] where value mtime

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

	    ::set isglobal [expr { ($where eq "G") ? "G " : "  " }]
	    if {$mtime ne {}} {
		::set mtime [clock format $mtime]
	    }

	    $t add $isglobal$name $value $mtime
	}
    }] show
    return
}

proc ::fx::config::get {config} {
    fossil show-repository-location
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
	fossil show-repository-location
	config set-local $name $value
	set current [config get-local $name]
    }

    puts '$current'
    return
}

proc ::fx::config::unset {config} {
    ::set global [$config @global]

    if {$global} {
	::set r [fossil global-location]
    } else {
	::set r [fossil repository-location]
    }
    # TODO: Reformat r to show relative to cwd

    foreach name [$config @setting] {
	puts -nonewline "Unsetting $r (${name})"

	# This one of two places has to distinguish global/local on get
	# based on the user's choice, instead of the regular heuristics
	# (local, global, default|error).
	if {$global} {
	    config unset-global $name $value
	} else {
	    fossil show-repository-location
	    config unset-local $name $value
	}

	puts ""
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::config 0
return
