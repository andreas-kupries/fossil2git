## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::map 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require cmdr::color
package require debug
package require debug::caller
package require interp
package require linenoise
package require textutil::adjust
package require try

package require fx::fossil
package require fx::mgr::map
package require fx::table
package require fx::util
package require fx::validate::map

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::map {
    namespace export \
	list create delete rename export import \
	add remove show
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::fx::fossil
    namespace import ::fx::util

    namespace import ::fx::table::do
    rename do table

    namespace import ::fx::mgr::map
    rename map mgr

    # After the manager has been handled, avoid conflict.
    namespace import ::fx::validate::map
}

# # ## ### ##### ######## ############# ######################

debug level  fx/map
debug prefix fx/map {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::fx::map::list {config} {
    debug.fx/map {}
    fossil show-repository-location

    set maps [fossil fx-maps]
    [table t {Name} {
	foreach m [lsort -dict $maps] {
	    $t add $m
	}
    }] show
    return
}

proc ::fx::map::create {config} {
    debug.fx/map {}
    fossil show-repository-location

    $config @newmap
    set map [$config @newmap string]

    puts -nonewline "Creating mapping \"[color note $map]\" ... "
    mgr create $map
    puts [color good OK]
    return
}

proc ::fx::map::delete {config} {
    debug.fx/map {}
    fossil show-repository-location

    $config @map
    set map [$config @map string]

    puts -nonewline "Deleting mapping \"[color note $map]\" ..."
    mgr delete $map
    puts [color good OK]
    return
}

proc ::fx::map::rename {config} {
    debug.fx/map {}
    fossil show-repository-location

    $config @map
    set old [$config @map string]

    $config @newmap
    set new [$config @newmap string]

    puts -nonewline "Renaming mapping \"[color note $old]\" to \"[color note $new]\" ..."
    fossil transaction {
	set items [mgr get $old]
	mgr delete $old
	mgr create $new
	if {[llength $items]} {
	    puts ""
	    AddBulk $new $items
	}
    }
    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::map::add {config} {
    debug.fx/map {}
    fossil show-repository-location

    $config @map
    set map [$config @map string]

    set key   [$config @key]
    set value [$config @value]

    puts "Mapping \"$map\":"
    AddBulk $map [::list $key $value]
    puts [color good OK]
    return
}

proc ::fx::map::AddBulk {map dict} {
    debug.fx/map {}
    fossil repository transaction {
	foreach {key value} $dict {
	puts "  Map \"$key\" -> \"$value\" ... "
	    mgr add1 $map $key $value
	}
    }
    return
}

proc ::fx::map::remove {config} {
    debug.fx/map {}
    fossil show-repository-location

    $config @map
    set map [$config @map string]

    puts "Mapping \"$map\":"
    fossil repository transaction {
	foreach item [$config @items] {
	    puts "  Removing key \"$item\" ... "
	    mgr remove1 $map $item
	}
    }
    puts [color good OK]
    return
}

proc ::fx::map::show {config} {
    debug.fx/map {}
    fossil show-repository-location

    $config @map
    set map [$config @map string]

    puts "Mapping \"$map\":"
    [table t {Key Value} {
	foreach {key value} [mgr get $map] {
	    $t add $key $value
	}
    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::map::export {config} {
    debug.fx/map {}
    fossil show-repository-location

    $config @maps

    if {[$config @maps set?]} {
	set maps [$config @maps string]
    } else {
	set maps [fossil fx-maps]
    }

    lappend data "\# fx mapping export @ [clock format [clock seconds]]"
    foreach map $maps {
	lappend data [::list map $map]
	foreach {key value} [mgr get $map] {
	    lappend data [::list item $key $value]
	}
	lappend data end
    }

    set    chan [open [$config @output] w]
    puts  $chan [join $data \n]
    close $chan
    return
}

proc ::fx::map::import {config} {
    debug.fx/map {}
    fossil show-repository-location

    set extend [$config @extend]

    set input [$config @input]
    set data [read $input]
    $config @input forget

    # Run the import script in a safe interpreter with just the import
    # commands. This generates internal data structures from which we
    # then create the mappings again. We catch issues and report them,
    # but do not abort importing.

    set i [interp::createEmpty]
    $i alias map  ::fx::map::IMap
    $i alias item ::fx::map::IItem
    $i alias end  ::fx::map::IEnd
    $i eval $data
    interp delete $i

    if {!$extend} {
	puts [color warning "Import replaces all existing mappings ..."]
	# Inlined delete of all mappings.
	foreach map [fossil fx-maps] {
	    puts -nonewline "Deleting mapping \"[color note $map]\" ..."
	    mgr delete $map
	    puts [color good OK]
	}
    } else {
	puts [color note "Import keeps the existing mappings ..."]
    }

    variable imported
    if {![llength $imported]} {
	puts [color note {No mappings}]
	return
    }

    puts "New mappings ..."
    foreach {map items} $imported {
	puts -nonewline "  Importing $map ([expr {[llength $items] /2}]) ... "
	flush stdout

	if {[mgr has $map]} {
	    puts [color warning "Ignored, already known"]
	    continue
	}
	try {
	    mgr create $map
	    if {[llength $items]} {
		puts ""
		AddBulk $map $items
	    }
	} on error {e o} {
	    puts [color error $e]
	} on ok {e o} {
	    puts [color good OK]
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::fx::map::IMap {name} {
    debug.fx/map {}
    variable current $name
    variable citems {}
    return
}
proc ::fx::map::IItem {key value} {
    debug.fx/map {}
    # No validation, we do not have proper a context (a created/known
    # mapping) here.
    variable citems
    lappend  citems $key $value
    return
}
proc ::fx::map::IEnd {} {
    debug.fx/map {}
    variable current
    variable citems
    variable imported
    lappend  imported $current $citems
    set current {}
    set citems {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::map 0
return
