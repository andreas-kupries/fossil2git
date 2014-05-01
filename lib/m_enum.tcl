## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::mgr::enum 0
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

package require fx::fossil
package require fx::validate::enum

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::mgr::enum {
    namespace export \
	items create delete \
	add add1 remove remove1 change
    namespace ensemble create

    namespace import ::fx::fossil
    namespace import ::fx::validate::enum
}

# # ## ### ##### ######## ############# ######################

debug level  fx/mgr/enum
debug prefix fx/mgr/enum {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::fx::mgr::enum::items {name} {
    debug.fx/mgr/enum {}
    set etable [enum table-of $name]
    return [fossil repository eval [subst {
	SELECT item
	FROM   "$etable"
    }]]
    return
}

proc ::fx::mgr::enum::create {name} {
    debug.fx/mgr/enum {}
    set etable [enum table-of $name]
    fossil repository transaction {
	fossil repository eval [subst {
	    CREATE TABLE "$etable" (
		id   INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
		item TEXT    UNIQUE
	    );
	}]
    }
    return
}

proc ::fx::mgr::enum::delete {name} {
    debug.fx/mgr/enum {}
    set etable [enum table-of $name]
    fossil repository transaction {
	fossil repository eval [subst {
	    DROP TABLE "$etable"
	}]
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mgr::enum::add {name items} {
    debug.fx/mgr/enum {}
    set etable [enum table-of $name]

    fossil repository transaction {
	foreach item $items {
	    fossil repository eval [subst {
		INSERT
		INTO "$etable"
		VALUES (NULL, :item)
	    }]
	}
    }
    return
}

proc ::fx::mgr::enum::add1 {name item} {
    debug.fx/mgr/enum {}
    set etable [enum table-of $name]
    fossil repository transaction {
	fossil repository eval [subst {
	    INSERT
	    INTO "$etable"
	    VALUES (NULL, :item)
	}]
    }
    return
}

proc ::fx::mgr::enum::remove {name items} {
    debug.fx/mgr/enum {}
    set etable [enum table-of $name]
    fossil repository transaction {
	foreach item $items {
	    fossil repository eval [subst {
		DELETE
		FROM "$etable"
		WHERE item = :item
	    }]
	}
    }
    return
}

proc ::fx::mgr::enum::remove1 {name item} {
    debug.fx/mgr/enum {}
    set etable [enum table-of $name]
    fossil repository transaction {
	fossil repository eval [subst {
	    DELETE
	    FROM "$etable"
	    WHERE item = :item
	}]
    }
    return
}

proc ::fx::mgr::enum::change {name old new} {
    debug.fx/mgr/enum {}
    set etable [enum table-of $name]
    fossil repository transaction {
	fossil repository eval [subst {
	    UPDATE "$etable"
	    SET   item = :new
	    WHERE item = :old
	}]
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::mgr::enum 0
return
