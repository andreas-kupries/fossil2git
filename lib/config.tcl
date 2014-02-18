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
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::config {
    namespace export available list get set unset
    namespace ensemble create

    namespace import ::fx::table::do
    rename do table

    # Assumed database schema
    # Table "config"
    # Columns name  TEXT PK
    # Columns mtime DATE
    # Columns value CLOB
}

# # ## ### ##### ######## ############# ######################

proc ::fx::config::available {config} {
    variable legal
    puts [join [lsort -dict [dict keys $legal]] \n]
}

proc ::fx::config::list {config} {
    # TODO: order by name, or last-changed
    # Currently fixed order by name.

    [table t {Setting Last-Changed Value} {
	[$config @repository-db] eval {
	    SELECT name, value, mtime
	    FROM   config
	    ORDER BY name
	    ;
	} {
	    if {[string match ckout:*     $name]} continue
	    if {[string match peer-*      $name]} continue
	    if {[string match subrepo:*   $name]} continue
	    if {[string match skin:*      $name]} continue
	    if {[string match baseurl:*   $name]} continue
	    if {[string match last-sync-* $name]} continue

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

	    $t add $name [clock format $mtime] $value
	}
    }] show
    return
}

proc ::fx::config::get {config} {
    ::set name [$config @setting]
    puts [[$config @repository-db] onecolumn {
	SELECT value
	FROM  config
	WHERE name  = :name
	;
    }]
    return
}

proc ::fx::config::set {config} {
    ::set name  [$config @setting]
    ::set value [$config @value]
    ::set r     [$config @repository] ;# TODO: Reformat to show relative to cwd
    ::set db    [$config @repository-db]
    ::set now   [clock seconds]

    puts -nonewline "Setting $r (${name}): "
    $db transaction {
	# Change ...
	$db eval {
	    # Idea, remembering something on the sqlite list:
	    # Have entry => Insert skips, Update changes.
	    # No entry   => Insert acts,  Update is no-op.

	    INSERT OR IGNORE INTO config
	    VALUES (:name, :value, :now)
	    ;
	    UPDATE config
	    SET   value = :value,
	          mtime = :now
	    WHERE name  = :name
	    ;
	}
    }

    # Show actual value found in the database.
    puts '[$db onecolumn {
	    SELECT value
	    FROM  config
	    WHERE name  = :name
	    ;
    }]'
    return
}


proc ::fx::config::unset {config} {
    ::set name  [$config @setting]
    ::set r     [$config @repository] ;# TODO: Reformat to show relative to cwd
    ::set db    [$config @repository-db]

    puts -nonewline "Unsetting $r (${name})"
    $db transaction {
	$db eval {
	    DELETE
	    FROM config
	    WHERE name  = :name
	    ;
	}
    }
    puts ""
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::config 0
return
