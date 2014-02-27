## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::mgr::config 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require fx::fossil
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::mgr {
    namespace export config
    namespace ensemble create
}

namespace eval ::fx::mgr::config {
    namespace export \
	get-list get get-with-default has \
	get-local get-global has-glob unset-glob \
	get-list-global get-extended-with-default \
	set-global set-local unset-global unset-local \
	unset-glob-global unset-glob-local
    namespace ensemble create

    namespace import ::fx::fossil

    # Assumed database schema
    #
    # LOCAL (repository)
    # =======================
    # Table "config"
    # Column name  TEXT PK
    # Column mtime DATE
    # Column value CLOB
    #
    # GLOBAL ~/.fossil
    # =======================
    # Table "global_config"
    # Column name  TEXT PK
    # Column value CLOB
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mgr::config::get-list {} {
    set config {}
    get-list-global {
	dict set config $name [list G $value $mtime]
    }
    get-list-local {
	dict set config $name [list L $value $mtime]
    }
    return $config
}

proc ::fx::mgr::config::get {name} {
    fossil repository transaction {
	if {[has-local $name]} {
	   return [get-local $name]
	}
    }
    fossil global transaction {
	if {[has-global $name]} {
	   return [get-global $name]
	}
    }
    return -code error \
	-errorcode {FX CONFIG GET UNKNOWN} \
	"Unknown config key $name"
}

proc ::fx::mgr::config::get-with-default {name default} {
    fossil repository transaction {
	if {[has-local $name]} {
	   return [get-local $name]
	}
    }
    fossil global transaction {
	if {[has-global $name]} {
	   return [get-global $name]
	}
    }
    return $default
}

proc ::fx::mgr::config::get-extended-with-default {name default} {
    fossil repository transaction {
	if {[has-local $name]} {
	   return [get-extended-local $name]
	}
    }
    fossil global transaction {
	if {[has-global $name]} {
	   return [get-extended-global $name]
	}
    }
    return [list -1 {} $default]
}

proc ::fx::mgr::config::has {name} {
    return [expr { [has-local  $name] ||
		   [has-global $name] }]
}

proc ::fx::mgr::config::has-glob {pattern} {
    return [expr { [has-glob-local  $pattern] ||
		   [has-glob-global $pattern] }]
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mgr::config::get-list-local {script} {
    upvar 1 name name value value mtime mtime
    fossil repository eval {
	SELECT name, value, mtime
	FROM   config
    } {
	uplevel 1 $script
    }
    return
}

proc ::fx::mgr::config::get-list-global {script} {
    upvar 1 name name value value mtime mtime
    fossil global eval {
	SELECT name, value
	FROM   global_config
    } {
	set mtime {}
	uplevel 1 $script
    }
    return
}

proc ::fx::mgr::config::get-local {name} {
    return [fossil repository onecolumn {
	SELECT value
	FROM  config
	WHERE name  = :name
    }]
}

proc ::fx::mgr::config::get-global {name} {
    return [fossil global onecolumn {
	SELECT value
	FROM  global_config
	WHERE name  = :name
    }]
}

proc ::fx::mgr::config::get-extended-local {name} {
    return [fossil repository eval {
	SELECT '0', mtime, value
	FROM  config
	WHERE name  = :name
    }]
}

proc ::fx::mgr::config::get-extended-global {name} {
    return [fossil global eval {
	SELECT '1', '', value
	FROM  global_config
	WHERE name  = :name
    }]
}

proc ::fx::mgr::config::has-local {name} {
    return [fossil repository onecolumn {
	SELECT count(*)
	FROM  config
	WHERE name  = :name
    }]
}

proc ::fx::mgr::config::has-global {name} {
    return [fossil global onecolumn {
	SELECT count(*)
	FROM  global_config
	WHERE name  = :name
    }]
}

proc ::fx::mgr::config::has-glob-local {pattern} {
    return [fossil repository onecolumn {
	SELECT count(*)
	FROM  config
	WHERE name GLOB :pattern
    }]
}

proc ::fx::mgr::config::has-glob-global {pattern} {
    return [fossil global onecolumn {
	SELECT count(*)
	FROM  global_config
	WHERE name GLOB :pattern
    }]
}

proc ::fx::mgr::config::set-local {name value} {
    set now [clock seconds]
    fossil repository transaction {
	# Tricky code handling setting a value for a non-existing key,
	# or overwriting the value of an existing one.
	# 
	# (1) We have an entry for 'name'.
	#     => INSERT fails, and IGNOREs that, making it a no-op.
	#     => UPDATE finds the entry and modifies it.
	# (2) There is no entry for 'name'.
	#     => INSERT creates the entry.
	#     => UPDATE changes the entry to the same value, a no-op.
	fossil repository eval {
	    INSERT OR IGNORE INTO config
	    VALUES (:name, :value, :now);

	    UPDATE config
	    SET   value = :value,
	          mtime = :now
	    WHERE name  = :name
	}
    }
    return
}

proc ::fx::mgr::config::set-global {name value} {
    fossil global transaction {
	# Tricky code handling setting a value for a non-existing key,
	# or overwriting the value of an existing one.
	# 
	# (1) We have an entry for 'name'.
	#     => INSERT fails, and IGNOREs that, making it a no-op.
	#     => UPDATE finds the entry and modifies it.
	# (2) There is no entry for 'name'.
	#     => INSERT creates the entry.
	#     => UPDATE changes the entry to the same value, a no-op.
	fossil global eval {
	    INSERT OR IGNORE INTO global_config
	    VALUES (:name, :value);

	    UPDATE global_config
	    SET   value = :value
	    WHERE name  = :name
	}
    }
    return
}

proc ::fx::mgr::config::unset-local {name} {
    fossil repository transaction {
	fossil repository eval {
	    DELETE
	    FROM config
	    WHERE name = :name
	}
    }
    return [fossil repository changes]
}

proc ::fx::mgr::config::unset-global {name} {
    fossil global transaction {
	fossil global eval {
	    DELETE
	    FROM global_config
	    WHERE name = :name
	}
    }
    return [fossil global changes]
}

proc ::fx::mgr::config::unset-glob-local {pattern} {
    fossil repository transaction {
	fossil repository eval {
	    DELETE
	    FROM config
	    WHERE name GLOB :pattern
	}
    }
    return [fossil repository changes]
}

proc ::fx::mgr::config::unset-glob-global {pattern} {
    fossil global transaction {
	fossil global eval {
	    DELETE
	    FROM global_config
	    WHERE name GLOB :pattern
	}
    }
    return [fossil global changes]
}

# # ## ### ##### ######## ############# ######################
package provide fx::mgr::config 0
return
