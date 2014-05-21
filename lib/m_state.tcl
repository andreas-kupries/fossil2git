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
package require fx::fossil

# # ## ### ##### ######## ############# ######################

namespace eval ::fx {
    namespace export mgr
    namespace ensemble create
}

namespace eval ::fx::mgr {
    namespace export state
    namespace ensemble create
}

namespace eval ::fx::mgr::state {
    namespace export register list \
	begin done table-rids? table? table table_start table_end row sql sep module
    namespace ensemble create

    namespace import ::fx::fossil

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

proc ::fx::mgr::state::begin {path} {
    debug.fx/mgr/state {}
    variable thechan [open $path w]
    return
}

proc ::fx::mgr::state::done {} {
    debug.fx/mgr/state {}
    variable thechan
    close $thechan
    return
}

proc ::fx::mgr::state::table-rids? {table } {
    debug.fx/mgr/state {}

    # Tables which are just rid references into event (blob) need
    # special handling because rids are not constant from repository
    # to repository, only uuid's are. So, on saving we convert the
    # local rids to uuids and put them into a temp table. On import we
    # convert the uuids of the temp table back to local rids.

    if {![fossil has   $table]} return
    if { [fossil empty $table]} return

    sep
    sql {
	CREATE TEMP TABLE fx_aku_temp_uuid ( uuid TEXT UNIQUE );
    }

    #state table? $table {id 0} -- Convert rid to uuid and save
    table_start fx_aku_temp_uuid
    fossil repository eval [subst {
	    SELECT B.uuid AS uuid
	    FROM "$table" S, blob B
	    WHERE B.rid = S.id
    }] {
	row "\"$uuid\""
    }
    table_end
    # Convert uuid to rid and restore.
    sql [subst {
	INSERT INTO "$table"
	SELECT rid
	FROM   blob
	WHERE blob.uuid IN fx_aku_temp_uuid;

	DROP TABLE fx_aku_temp_uuid;
    }]
    return
}

proc ::fx::mgr::state::table? {table colspec} {
    # Unknown table ? Ignore
    if {![fossil has $table]} return
    table $table $colspec
    return
}

proc ::fx::mgr::state::table {table colspec} {
    debug.fx/mgr/state {}
    set names {}
    set rowcmd "row"

    # Nothing to dump ? Skip
    if {[fossil empty $table]} return

    foreach {name quote} $colspec {
	lappend names $name
	if {$quote} {
	    set ref " '\$$name'"
	} else {
	    set ref " \$$name"
	}
	append rowcmd $ref
    }

    set names [join $names ,]

    debug.fx/mgr/state {names  = ($names)}
    debug.fx/mgr/state {rowcmd = ($rowcmd)}

    table_start $table
    fossil repository eval [subst {
	SELECT $names FROM "$table"
    }] $rowcmd
    table_end
    return
}

proc ::fx::mgr::state::table_start {table} {
    debug.fx/mgr/state {}
    variable prefix
    sql "INSERT INTO \"$table\""
    # Initial prefix
    set prefix "VALUES "
    return
}

proc ::fx::mgr::state::row {args} {
    debug.fx/mgr/state {}
    variable prefix
    sql "${prefix}([join $args {, }])"
    # Set for non-initial rows
    set prefix "      ,"
    return
}

proc ::fx::mgr::state::table_end {} {
    debug.fx/mgr/state {}
    variable prefix
    unset    prefix
    sql ";\n"
    return
}

proc ::fx::mgr::state::sql {text} {
    debug.fx/mgr/state {}
    variable thechan
    puts $thechan $text
    return
}

proc ::fx::mgr::state::module {text} {
    debug.fx/mgr/state {}
    variable thechan
    puts $thechan "-- FX STATE -- Module ($text) --"
    sep
    return
}

proc ::fx::mgr::state::sep {} {
    debug.fx/mgr/state {}
    variable thechan
    puts $thechan "-- [string repeat - 69]"
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::mgr::state 0
return
