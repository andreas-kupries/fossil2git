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
package require fx::table
package require fx::util
package require fx::validate::enum

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::enum {
    namespace export list create delete export import add remove change
    namespace ensemble create

    namespace import ::fx::color
    namespace import ::fx::fossil
    namespace import ::fx::util
    namespace import ::fx::validate::enum

    namespace import ::fx::table::do
    rename do table
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

    [table t {Name Elements} {
	foreach e $enums {
	    set etable [enum table-of $e]
	    set item [fossil repository eval [subst {
		SELECT item
		FROM   "$etable"
		ORDER BY item
	    }]]
	    set items [join $items {, }]
	    set items [textutil::adjust::adjust $items -length $w]
	    $t add $e $items
	}
    }] show
    return
}

proc ::fx::enum::create {config} {
    debug.fx/enum {}
    fossil show-repository-location

    set etable [$config @newenum]
    set enum   [$config @newenum string]
    puts -nonewline "Creating enum \"$enum\" ... "

    fossil repository transaction {
	fossil repository eval [subst {
	    CREATE TABLE "$etable" (
		id   INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
		item TEXT    UNIQUE
	    );
	}]

	set prefix \n
	foreach item [lsort -unique [$config @items]] {
	    puts "$prefix  Adding item \"$item\" ... "
	    fossil repository eval [subst {
		INSERT
		INTO "$etable"
		VALUES (NULL, :item)
	    }]
	    set prefix {}
	}
    }
    puts [color good OK]
    return
}

proc ::fx::enum::delete {config} {
    debug.fx/enum {}
    fossil show-repository-location

    set etable [$config @enum]
    set enum   [$config @enum string]
    puts -nonewline "Deleting enum \"$enum\" ..."

    fossil repository transaction {
	fossil repository eval [subst {
	    DROP TABLE "$etable"
	}]
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::enum::add {config} {
    debug.fx/enum {}
    fossil show-repository-location

    set etable [$config @enum]
    set enum   [$config @enum string]
    puts "Enum \"$enum\":"

    fossil repository transaction {
	foreach item [lsort -unique [$config @items]] {
	    puts "  Adding item \"$item\" ... "
	    fossil repository eval [subst {
		INSERT
		INTO "$etable"
		VALUES (NULL, :item)
	    }]
	}
    }

    puts [color good OK]
    return
}

proc ::fx::enum::remove {config} {
    debug.fx/enum {}
    fossil show-repository-location

    set etable [$config @enum]
    set enum   [$config @enum string]
    puts "Enum \"$enum\":"

    fossil repository transaction {
	foreach item [lsort -unique [$config @items]] {
	    puts "  Removing item \"$item\" ... "
	    fossil repository eval [subst {
		DELETE
		FROM "$etable"
		WHERE item = :item
	    }]
	}
    }

    puts [color good OK]
    return
}

proc ::fx::enum::change {config} {
    debug.fx/enum {}
    fossil show-repository-location

    set etable [$config @enum]
    set enum   [$config @enum string]
    set old    [$config @item]
    set new    [$config @newitem]

    puts "Enum \"$enum\":"

    puts "  Renaming item \"$old\" to \"$new\" ... "
    fossil repository transaction {
	fossil repository eval [subst {
	    UPDATE "$etable"
	    SET   item = :new
	    WHERE item = :old
	}]
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::enum::export {config} {
    debug.fx/enum {}
    #fossil show-repository-location

    set etables [$config @enums]
    set enums   [$config @enums string]
    set chan    [$config @output]

    lappend data "\# fx enumeration export @ [clock format [clock seconds]]"

    foreach etable $etables enum $enums {
	lappend data [::list enum $enum]

	fossil repository eval [subst {
	    SELECT item
	    FROM   "$etable"
	    ORDER BY item
	}] {
	    lappend data [::list item $item]
	}
	lappend data end
    }

    puts $chan [join $data \n]
    return
}

proc ::fx::enum::import {config} {
    debug.fx/enum {}
    fossil show-repository-location

    set input [$config @import]
    set data [read $input]
    $config @import forget

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

    variable imported
    foreach {enum items} $imported {
	puts -nonewline "Importing $enum ([llength $items]) "
	flush stdout

	try {
	    # Note: Recursion through the cmdr hierarchy. Validation
	    # of data happens now.
	    # TODO: Shortcut through internal command (no repeated
	    # display of repo location).

	    fx::fx do enum create $enum {*}$items
	} on error {e o} {
	    puts [color error $e]
	} on ok {e o} {
	    puts [color good OK]
	}
	flush stdout
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
