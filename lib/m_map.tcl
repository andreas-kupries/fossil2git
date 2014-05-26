## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::mgr::map 0
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
package require fx::mgr::state
package require fx::validate::map

# # ## ### ##### ######## ############# ######################

namespace eval ::fx {
    namespace export mgr
    namespace ensemble create
}

namespace eval ::fx::mgr {
    namespace export map
    namespace ensemble create
}

namespace eval ::fx::mgr::map {
    namespace export \
	has keys get create delete \
	add add1 remove remove1
    namespace ensemble create

    namespace import ::fx::fossil
    namespace import ::fx::mgr::state
    namespace import ::fx::validate::map

    variable dropsql   {DROP TABLE IF EXISTS "$etable";}
    variable createsql {
	CREATE TABLE IF NOT EXISTS
	"$etable"
        (
	 id    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	 key   TEXT    UNIQUE,
	 value TEXT
	);
    }
}

# # ## ### ##### ######## ############# ######################

debug level  fx/mgr/map
debug prefix fx/mgr/map {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::fx::mgr::map::has {name} {
    fossil has [map table-of $name]
}

proc ::fx::mgr::map::keys {name} {
    debug.fx/mgr/map {}
    return [fossil fx-map-keys [map table-of $name]]
}

proc ::fx::mgr::map::get {name} {
    debug.fx/mgr/map {}
    return [fossil fx-map-get [map table-of $name]]
}

proc ::fx::mgr::map::create {name} {
    debug.fx/mgr/map {}
    variable createsql
    set etable [map table-of $name]
    fossil repository transaction {
	# etable is subst'ed
	fossil repository eval [subst $createsql]
    }
    return
}

proc ::fx::mgr::map::delete {name} {
    debug.fx/mgr/map {}
    variable dropsql
    set etable [map table-of $name]
    fossil repository transaction {
	# etable is subst'ed
	fossil repository eval [subst $dropsql]
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mgr::map::add {name dict} {
    debug.fx/mgr/map {}
    set etable [map table-of $name]

    fossil repository transaction {
	foreach {key value} $dict {
	    fossil repository eval [subst {
		INSERT
		INTO "$etable"
		VALUES (NULL, :key, :value)
	    }]
	}
    }
    return
}

proc ::fx::mgr::map::add1 {name key value} {
    debug.fx/mgr/map {}
    set etable [map table-of $name]
    fossil repository transaction {
	fossil repository eval [subst {
	    INSERT
	    INTO "$etable"
	    VALUES (NULL, :key, :value)
	}]
    }
    return
}

proc ::fx::mgr::map::remove {name keys} {
    debug.fx/mgr/map {}
    set etable [map table-of $name]
    fossil repository transaction {
	foreach key $keys {
	    fossil repository eval [subst {
		DELETE
		FROM "$etable"
		WHERE key = :key
	    }]
	}
    }
    return
}

proc ::fx::mgr::map::remove1 {name key} {
    debug.fx/mgr/map {}
    set etable [map table-of $name]
    fossil repository transaction {
	fossil repository eval [subst {
	    DELETE
	    FROM "$etable"
	    WHERE key = :key
	}]
    }
    return
}

# # ## ### ##### ######## ############# ######################
fx::mgr::state::register ::fx::mgr::map::DUMP

proc ::fx::mgr::map::DUMP {} {
    variable dropsql
    variable createsql

    state module map
    foreach map [fossil fx-maps] {
	set etable [map table-of $map]
	# etable is subst'ed
	state sql [subst $dropsql]
	state sql [subst $createsql]
	state table $etable {id 0 key 1 value 1}
    }
    state sep
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::mgr::map 0
return
