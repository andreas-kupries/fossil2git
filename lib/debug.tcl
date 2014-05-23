## -*- tcl -*-
# # ## ### ##### ######## #############

# @@ Meta Begin
# Package fx::debug 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     sqlite3
# Meta subject     fossil
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require debug

package require fx::table

# # ## ### ##### ######## #############

namespace eval ::fx {
    namespace export debug
    namespace ensemble create
}
namespace eval ::fx::debug {
    namespace export levels
    namespace ensemble create

    namespace import ::fx::table::do
    rename do table
}

# # ## ### ##### ######## #############

proc ::fx::debug::levels {config} {
    # First ensure that all possible fx packages are loaded, so that
    # all possible debug levels are declared and known.

    package require fx::config
    package require fx::enum
    package require fx::fossil
    package require fx::mailer
    package require fx::mailgen
    package require fx::manifest
    package require fx::mgr::config
    package require fx::note
    package require fx::report
    package require fx::seen
    package require fx::table
    package require fx::user
    package require fx::user
    package require fx::validate::enum
    package require fx::validate::enum-item
    package require fx::validate::event-type
    package require fx::validate::mail-address
    package require fx::validate::mail-config
    package require fx::validate::not-enum
    package require fx::validate::not-enum-item
    package require fx::validate::setting
    package require fx::validate::ticket-field
    package require fx::validate::user
    package require fx::validate::uuid

    package require cmdr::tty
    package require cmdr::color
    package require cmdr::ask

    [table t {Level} {
	foreach level [lsort -dict [debug names]]  {
	    $t add $level
	}
    }] show
    return
}

# # ## ### ##### ######## #############
package provide fx::debug 0
