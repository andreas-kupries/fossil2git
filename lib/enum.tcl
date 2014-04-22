## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::enum 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require fx::table
package require fx::fossil
package require textutil::adjust
package require linenoise
package require interp
package require try

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::enum {
    namespace export list create delete export import add remove change
    namespace ensemble create

    namespace import ::fx::table::do
    namespace import ::fx::fossil::fx-enums
    rename do table
}

# # ## ### ##### ######## ############# ######################

proc ::fx::enum::MaxL {words} {
    ::set max 0 
    foreach w $words {
	set l [string length $w]
	if {$l <= $max} continue
	::set max $l
    }
    return $max
}

proc ::fx::enum::list {config} {
    [table t {Name Elements} {
	::set db    [$config @repository-db]
	::set enums [fx-enums]

	set w [expr {[linenoise columns] - [MaxL $enums] - 7}]

	foreach e $enums {
	    set items [join [$db eval [subst {
		SELECT item
		FROM   fx_aku_enum_$e
		ORDER BY item
	    }]] {, }]

	    set items [textutil::adjust::adjust $items -length $w]
	    $t add $e $items
	}
    }] show
}

proc ::fx::enum::create {config} {
    ::set db     [$config @repository-db]
    ::set etable [$config @newenum]

    $db transaction {
	$db eval [subst {
	    CREATE TABLE $etable (
		id   INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
		item TEXT    UNIQUE
	    );
	}]

	foreach item [lsort -unique [$config @items]] {
	    $db eval [subst {
		INSERT INTO $etable VALUES (NULL, :item)
	    }]
	}
    }
    return
}

proc ::fx::enum::delete {config} {
    ::set db     [$config @repository-db]
    ::set etable [$config @enum]

    $db transaction {
	$db eval [subst {
	    DROP TABLE $etable
	}]
    }
    return
}

proc ::fx::enum::export {config} {
    ::set db      [$config @repository-db]
    ::set etables [$config @enums]
    ::set chan    [$config @output]

    lappend data "\# fx enumeration export @ [clock format [clock seconds]]"

    foreach etable $etables {
	regsub {^fx_aku_enum_} $etable {} name
	lappend data [::list enum $name]

	$db eval [subst {
	    SELECT item
	    FROM   $etable
	    ORDER BY item
	    ;
	}] {
	    lappend data [::list item $item]
	}
	lappend data end
    }
    puts $chan [join $data \n]
    return
}

proc ::fx::enum::import {config} {
    ::set db    [$config @repository-db]
    ::set input [$config @import]

    ::set data [read $input]
    close $input

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
	    fx::fx do enum create $enum {*}$items
	} on error {e o} {
	    puts $e
	} on ok {e o} {
	    puts OK
	}
	flush stdout
    }
    return
}

proc ::fx::enum::IEnum {name} {
    variable current $name
    variable citems {}
    return
}
proc ::fx::enum::IItem {item} {
    variable citems
    lappend  citems $item
    return
}
proc ::fx::enum::IEnd {} {
    variable current
    variable citems
    variable imported
    lappend  imported $current $citems
    set current {}
    set citems {}
    return
}

proc ::fx::enum::add {config} {
    ::set db     [$config @repository-db]
    ::set etable [$config @enum]

    $db transaction {
	foreach item [lsort -unique [$config @items]] {
	    $db eval [subst {
		INSERT INTO $etable VALUES (NULL, :item)
	    }]
	}
    }
    return
}

proc ::fx::enum::remove {config} {
    ::set db     [$config @repository-db]
    ::set etable [$config @enum]

    $db transaction {
	foreach item [lsort -unique [$config @items]] {
	    $db eval [subst {
		DELETE
		FROM $etable
		WHERE item = :item
	    }]
	}
    }
    return
}

proc ::fx::enum::change {config} {
    ::set db     [$config @repository-db]
    ::set etable [$config @enum]
    ::set old    [$config @item]
    ::set new    [$config @newitem]

    $db transaction {
	$db eval [subst {
	    UPDATE $etable
	    SET   item = :new
	    WHERE item = :old
	}]
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::enum 0
return
