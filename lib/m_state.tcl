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

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::mgr::state {
    namespace export register list \
	begin done table_start table_end row sql sep module
    namespace ensemble create

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

proc ::fx::mgr::state::begin {chan} {
    debug.fx/mgr/state {}
    variable thechan $chan
    return
}

proc ::fx::mgr::state::done {} {
    debug.fx/mgr/state {}
    variable thechan
    close $thechan
    return
}

proc ::fx::mgr::state::table {table colspec} {
    debug.fx/mgr/state {}
    set names {}
    set rowcmd "row "

    foreach col $colspec {
	lassign $col name quote
	lappend names $name
	if {$quote} {
	    set ref "\"\$$name\""
	} else {
	    set ref "\$$name"
	}
	append rowcmd $ref
    }

    set names [join $names ,]

    debug.fx/mgr/state {names  = ($names)}
    debug.fx/mgr/state {rowcmd = ($rowcmd)}

    table_begin $table
    fossil repository eval [subst {
	SELECT $names FROM "$table"
    }] $rowcmd
    table_end
    return
}

proc ::fx::mgr::state::table_start {table} {
    debug.fx/mgr/state {}
    sql "INSERT INTO $table"
    return
}

proc ::fx::mgr::state::table_end {} {
    debug.fx/mgr/state {}
    variable prefix
    unset    prefix
    sql ";"
    return
}

proc ::fx::mgr::state::row {args} {
    debug.fx/mgr/state {}
    variable prefix
    if {![info exists prefix]} { set prefix "VALUES " }
    sql "${prefix}([join$args {, }])"
    set prefix "      ,"
    return
}

proc ::fx::mgr::state::sql {text} {
    debug.fx/mgr/state {}
    variable thechan
    put $thechan $sql
    return
}

proc ::fx::mgr::state::module {text} {
    debug.fx/mgr/state {}
    variable thechan
    put $thechan "-- FX STATE -- Module ($text) --"
    sep
    return
}

proc ::fx::mgr::state::sep {} {
    debug.fx/mgr/state {}
    variable thechan
    put $thechan "-- [string repeat 69 -]"
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::mgr::state 0
return
