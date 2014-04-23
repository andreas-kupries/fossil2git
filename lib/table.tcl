# -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# # ## ### ##### ######## ############# #####################

# @@ Meta Begin
# Package fx::table 0
# Meta author      ?
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require TclOO
package require struct::matrix
package require report

::report::defstyle table/table {} {
    data	set [split "[string repeat "| "   [columns]]|"]
    top		set [split "[string repeat "+ - " [columns]]+"]
    bottom	set [top get]
    topdata	set [data get]
    topcapsep	set [top get]
    top		enable
    bottom	enable
    topcapsep	enable
    tcaption	1
    for {set i 0 ; set n [columns]} {$i < $n} {incr i} {
	pad $i both { }
    }
    return
}

namespace eval ::fx::table {
    namespace export do
}

# # ## ### ##### ######## ############# #####################

proc ::fx::table::do {v headings script} {
    upvar 1 $v t
    set t [uplevel 1 [list ::fx::table new {*}$headings]]
    uplevel 1 $script
    return $t
}

oo::class create ::fx::table {
    # # ## ### ##### ######## #############

    constructor {args} {
	struct::matrix [self namespace]::M
	M add columns [llength $args]
	M add row $args
	set myplain 0
	set myheader 1
	return
    }

    destructor {}

    # # ## ### ##### ######## #############
    ## API

    # method names +, <<, => did not work ?!

    method add {args} {
	M add row $args
	return
    }

    method show {{cmd puts}} {
	uplevel 1 [list {*}$cmd [my String]]
	my destroy
	return
    }

    method show* {{cmd puts}} {
	uplevel 1 [list {*}$cmd [my String]]
	return
    }

    method plain {} {
	set myplain 1
    }

    method noheader {} {
	if {!$myheader} return
	set myheader 0
	M delete row 0
	return
    }

    method String {} {
	if {$myplain} {
	    set str [M format 2string]
	} else {
	    set r [report::report [self namespace]::R [M columns] style table/table]
	    set str [M format 2string $r]
	    $r destroy
	}
	return [string trimright $str]
    }

    # # ## ### ##### ######## #############
    ## Internal commands.

    # # ## ### ##### ######## #############
    ## State

    variable myplain myheader

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide fx::table 0
