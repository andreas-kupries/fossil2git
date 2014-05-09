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
	begin done table? table table_start table_end row sql sep module
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
