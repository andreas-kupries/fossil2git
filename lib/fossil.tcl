## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::fossil 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta require     sqlite3
# Meta subject     fossil
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require sqlite3

namespace eval ::fx::fossil {
    namespace export locate repository
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc fx::fossil::repository {p} {
    # cmdr generate callback

    # NOTE how we are keeping the repository database until process
    # end.  Assumes that locate is called only once. See also fx cmdr
    # specification.

    sqlite3 ::fx::fossil::R [$p config @repository]
    return  ::fx::fossil::R
}

proc fx::fossil::locate {p} {
    # cmdr generate callback

    # NOTE how we are keeping the checkout database until process end.
    # Assumes that locate is called only once. See also fx cmdr
    # specification.

    sqlite3 CK [ckout [scan-up Repository [pwd] fx::fossil::is]]

    return [file normalize [CK onecolumn {
	SELECT value
	FROM vvar
	WHERE name = 'repository'
    }]]
}

proc fx::fossil::is {dir} {
    foreach control {
	_FOSSIL_
	.fslckout
	.fos
    } {
	set control $dir/$control
	if {[file exists $control] &&
	    [file isfile $control]
	} {return 1}
    }
    return 0
}

proc fx::fossil::ckout {dir} {
    foreach control {
	_FOSSIL_
	.fslckout
	.fos
    } {
	set control $dir/$control
	if {[file exists $control] &&
	    [file isfile $control]
	} {return $control}
    }
    return -code error \
	-errorcode {FX FOSSIL CHECKOUT} \
	"Not a checkout: $dir"
}

proc fx::fossil::scan-up {this dir predicate} {
    set dir [file normalize $dir]
    while {1} {
	# Found the proper directory, per the predicate.
	if {[{*}$predicate $dir]} {
	    return $dir
	}

	# Not found, walk to parent
	set new [file dirname $dir]

	# Stop when reaching the root.
	if {$new eq $dir} { return {} }
	if {$new eq {}} { return {} }

	# Ok, truly walk up.
	set dir $new
    }
    return -code error \
	-error {FX FOSSIL SCAN-UP} \
	"$this not found"
}

# # ## ### ##### ######## ############# ######################
package provide fx::fossil 0
return
