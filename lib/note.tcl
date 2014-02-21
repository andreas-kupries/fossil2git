## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::note 0
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

namespace eval ::fx::note {
    namespace export \
	mail-config-show mail-config-set mail-config-unset \
	route-add route-list route-drop deliver
    namespace ensemble create

    namespace import ::fx::mgr::config
    namespace import ::fx::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::mail-config-show {config} {

    set settings [config get-list [$config @repository]]
    set settings [dict filter $settings key fx-aku-note-*]

    # Should possibly add info for missing keys, i.e. their defaults.
    # fx-aku-note-mail-debug	0
    # fx-aku-note-mail-tls	0
    # fx-aku-note-mail-user	''
    # fx-aku-note-mail-password	''
    # fx-aku-note-mail-host	localhost
    # fx-aku-note-mail-port	25
    # fx-aku-note-mail-sender	''	Mandatory

    # TODO: Have to drop the keys holding the route information.

    set data {}
    dict for {k v} $settings {
	lassign $v where mtime value
	regsub {^fx-aku-note-} $name {} name
	set isglobal [expr { ($where eq "G") ? "*" : "" }]
	if {$mtime ne {}} {
	    set mtime [clock format $mtime]
	}
	lappend data [list $name $isglobal $mtime $value]
    }

    [table t {Key Global Last-Changed Value} {
	foreach item [lsort -dict -index 0 $data] {
	    $t add {*}$item
	}
    }] show
    return
}

proc ::fx::note::mail-config-set {config} {
    # See also "fx::config::set"
    # equivalent with shorter user-visible keys

    set global [$config @global]
    set name   [$config @key]
    set value  [$config @value]
    set db     [$config @repository-db]

    puts -nonewline "Setting ${name}: "

    config set $global $db $name $value

    if {$global} {
	set current [config get-global $name]
	set suffix  " (global)"
    } else {
	set current [config get-local $db $name]
	set suffix  {}
    }

    puts '$current'$suffix
    return
}

proc ::fx::note::mail-config-unset {config} {
    set name   [$config @setting]
    set global [$config @global]

    puts -nonewline "Unsetting ${name}"

    config unset $global [$config @repository-db] $name

    puts ""
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::route-list {config} {
    # @repository
}

proc ::fx::note::route-add {config} {
    # @to (list), @event, @repository
    RouteAdd [$config @repository] \
	fx-aku-note-send2-[$config @event]: \
	[$config @to]
    return
}

proc ::fx::note::route-drop {config} {
    # @to (list), @event, @repository
}

proc ::fx::note::field-list {config} {
    # @repository
}

proc ::fx::note::route-field-add {config} {
    # @field (list), @repository
    RouteAdd [$config @repository] \
	fx-aku-note-field: \
	[$config @field]
    return
}

proc ::fx::note::route-field-drop {config} {
    # @field (list), @repository
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::route-deliver {config} {
    # @repository, @global, /... ?? --all how ?
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::RouteAdd {db prefix destinations} {
    set added 0

    foreach dst $destinations {
	puts -nonewline "  $dst ... "

	set key ${prefix}:$dst
	if {[config has $db $key]} {
	    puts "Already known"
	} else {
	    config set 0 $db $key
	    puts "Added"
	    incr added
	}
    }

    # TODO: if added => register repo in global.
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::note 0
return
