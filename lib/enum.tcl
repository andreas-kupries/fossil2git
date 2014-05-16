## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::enum 0
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
package require debug
package require debug::caller
package require interp
package require linenoise
package require textutil::adjust
package require try

package require fx::color
package require fx::fossil
package require fx::mgr::enum
package require fx::table
package require fx::util
package require fx::validate::enum

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::enum {
    namespace export \
	list create delete \
	export import \
	add remove change items
    namespace ensemble create

    namespace import ::fx::color
    namespace import ::fx::fossil
    namespace import ::fx::util

    namespace import ::fx::table::do
    rename do table

    namespace import ::fx::mgr::enum
    rename enum mgr

    # After the manager has been handled,
    # avoid conflict.
    namespace import ::fx::validate::enum
}

# # ## ### ##### ######## ############# ######################

debug level  fx/enum
debug prefix fx/enum {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::fx::enum::list {config} {
    debug.fx/enum {}
    fossil show-repository-location

    set enums [fossil fx-enums]
    set w     [expr {[linenoise columns] - [util max-length $enums] - 7}]

    # TODO: different modes of item formatting ? (one per line, vs block (current))

    [table t {Name Elements} {
	foreach e $enums {
	    set items [join [mgr items $e] {, }]
	    set items [textutil::adjust::adjust $items -length $w]
	    $t add $e $items
	}
    }] show
    return
}

proc ::fx::enum::create {config} {
    debug.fx/enum {}
    fossil show-repository-location

    $config @newenum
    set enum [$config @newenum string]

    puts -nonewline "Creating enumeration \"[color note $enum]\" ... "
    fossil repository transaction {
	mgr create $enum
	set items [$config @items]
	if {[llength $items]} {
	    puts ""
	    AddBulk $enum $items
	}
    }
    puts [color good OK]
    return
}

proc ::fx::enum::delete {config} {
    debug.fx/enum {}
    fossil show-repository-location

    $config @enum
    set enum [$config @enum string]

    puts -nonewline "Deleting enumeration \"[color note $enum]\" ..."
    mgr delete $enum
    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::enum::add {config} {
    debug.fx/enum {}
    fossil show-repository-location

    $config @enum
    set enum [$config @enum string]

    puts "Enumeration \"$enum\":"
    AddBulk $enum [$config @items]
    puts [color good OK]
    return
}

proc ::fx::enum::AddBulk {enum items} {
    debug.fx/enum {}
    fossil repository transaction {
	foreach item $items {
	    puts "  Adding item \"$item\" ... "
	    mgr add1 $enum $item
	}
    }
    return
}

proc ::fx::enum::remove {config} {
    debug.fx/enum {}
    fossil show-repository-location

    $config @enum
    set enum [$config @enum string]

    puts "Enumeration \"$enum\":"
    fossil repository transaction {
	foreach item [$config @items] {
	    puts "  Removing item \"$item\" ... "
	    mgr remove1 $enum $item
	}
    }
    puts [color good OK]
    return
}

proc ::fx::enum::change {config} {
    debug.fx/enum {}
    fossil show-repository-location

    $config @enum
    set enum [$config @enum string]
    set old  [$config @item]
    set new  [$config @newitem]

    puts "Enumeration \"$enum\":"
    puts "  Renaming item \"$old\" to \"$new\" ... "
    mgr change $enum $old $new
    puts [color good OK]
    return
}

proc ::fx::enum::items {config} {
    debug.fx/enum {}
    fossil show-repository-location

    $config @enum
    set enum [$config @enum string]

    puts "Enumeration \"$enum\":"
    [table t {\# Item} {
	set id 0
	foreach item [mgr items $enum] {
	    $t add $id $item
	    incr id
	}
    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::enum::export {config} {
    debug.fx/enum {}
    fossil show-repository-location

    $config @enums

    if {[$config @enums set?]} {
	set enums [$config @enums string]
    } else {
	set enums [fossil fx-enums]
    }
    set chan [$config @output]

    lappend data "\# fx enumeration export @ [clock format [clock seconds]]"
    foreach enum $enums {
	lappend data [::list enum $enum]
	foreach item [mgr items $enum] {
	    lappend data [::list item $item]
	}
	lappend data end
    }

    puts $chan [join $data \n]
    close $chan
    return
}

proc ::fx::enum::import {config} {
    debug.fx/enum {}
    fossil show-repository-location

    set extend [$config @extend]

    set input [$config @input]
    set data [read $input]
    $config @input forget

    # Run the import script in a safe interpreter with just the import
    # commands. This generates internal data structures from which we
    # then create the enumerations by looping back through the cmdr
    # hierarchy. This automatically gives us all the validation needed.
    # We catch issues and report them, but do not abort importing.

    set i [interp::createEmpty]
    $i alias enum ::fx::enum::IEnum
    $i alias item ::fx::enum::IItem
    $i alias end  ::fx::enum::IEnd
    $i eval $data
    interp delete $i

    if {!$extend} {
	puts [color warning "Import replaces all existing enumerations ..."]
	# Inlined delete of all enumerations.
	foreach enum [fossil fx-enums] {
	    puts -nonewline "Deleting enumeration \"[color note $enum]\" ..."
	    mgr delete $enum
	    puts [color good OK]
	}
    } else {
	puts [color note "Import keeps the existing enumerations ..."]
    }

    variable imported
    if {![llength $imported]} {
	puts [color note {No enumerations}]
	return
    }

    puts "New enumerations ..."
    foreach {enum items} $imported {
	puts -nonewline "  Importing $enum ([llength $items]) ... "
	flush stdout

	if {[mgr has $enum]} {
	    puts [color warning "Ignored, already known"]
	    continue
	}
	try {
	    mgr create $enum
	    if {[llength $items]} {
		puts ""
		AddBulk $enum $items
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

proc ::fx::enum::IEnum {name} {
    debug.fx/enum {}
    variable current $name
    variable citems {}
    return
}
proc ::fx::enum::IItem {item} {
    debug.fx/enum {}
    # No validation, we do not have proper a context (a created/known
    # enumeration) here.
    variable citems
    lappend  citems $item
    return
}
proc ::fx::enum::IEnd {} {
    debug.fx/enum {}
    variable current
    variable citems
    variable imported
    lappend  imported $current $citems
    set current {}
    set citems {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::enum 0
return
