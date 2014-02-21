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

namespace eval ::fx::mgr::config {
    namespace export \
	get-list get get-with-default has set unset \
	get-local get-global

    # TODO: has-glob, unset-glob

    namespace ensemble create

    namespace import fx::fossil

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

proc ::fx::mgr::config::get-list {db} {
    ::set config {}
    get-list-global {
	dict set config $name [list G $value $mtime]
    }
    get-list-local $db {
	dict set config $name [list L $value $mtime]
    }
    return $config
}

proc ::fx::config::get {db name} {
    $db transaction {
	if {[has-local $db $name]} {
	   return [get-local $db $name]
	}
    }
    [fossil global] transaction {
	if {[has-global $name]} {
	   return [get-global $name]
	}
    }
    return -code error \
	-errorcode {FX CONFI GET UNKNOWN} \
	"Unknown config key $name"
}

proc ::fx::config::get-with-default {db name default} {
    $db transaction {
	if {[has-local $db $name]} {
	   return [get-local $db $name]
	}
    }
    [fossil global] transaction {
	if {[has-global $name]} {
	   return [get-global $name]
	}
    }
    return $default
}

proc ::fx::config::has {db name} {
    return [expr { [has-local $db $name] ||
		   [has-global    $name] }]
}

proc ::fx::config::set {global db name $value} {
    if {$global} {
	set-global $name $value
    } else {
	set-local $db $name $value
    }
}

proc ::fx::config::unset {global db name} {
    if {$global} {
	unset-global $name
    } else {
	unset-local $db $name
    }
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mgr::config::get-list-local {db script} {
    upvar 1 name name value value mtime mtime
    $db eval {
	SELECT name, value, mtime
	FROM   config
    } {
	uplevel 1 $script
    }
}

proc ::fx::mgr::config::get-list-global {script} {
    upvar 1 name name value value mtime mtime
    [fossil global] eval {
	SELECT name, value
	FROM   global_config
    } {
	set mtime {}
	uplevel 1 $script
    }
}

proc ::fx::config::get-local {db name} {
    return [$db onecolumn {
	SELECT value
	FROM  config
	WHERE name  = :name
    }]
    return
}

proc ::fx::config::get-global {name} {
    return [[fossil global] onecolumn {
	SELECT value
	FROM  global_config
	WHERE name  = :name
    }]
    return
}

proc ::fx::config::has-local {db name} {
    return [$db onecolumn {
	SELECT count(*)
	FROM  config
	WHERE name  = :name
    }]
    return
}

proc ::fx::config::has-global {name} {
    return [[fossil global] onecolumn {
	SELECT count(*)
	FROM  global_config
	WHERE name  = :name
    }]
    return
}

proc ::fx::config::set-local {db name value} {
    ::set now [clock seconds]
    $db transaction {
	# Tricky code handling setting a value for a non-existing key,
	# or overwriting the value of an existing one.
	# 
	# (1) We have an entry for 'name'.
	#     => INSERT fails, and IGNOREs that, making it a no-op.
	#     => UPDATE finds the entry and modifies it.
	# (2) There is no entry for 'name'.
	#     => INSERT creates the entry.
	#     => UPDATE changes the entry to the same value, a no-op.
	$db eval {
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

proc ::fx::config::set-global {name value} {
    ::set db [fossil global]
    $db transaction {
	# Tricky code handling setting a value for a non-existing key,
	# or overwriting the value of an existing one.
	# 
	# (1) We have an entry for 'name'.
	#     => INSERT fails, and IGNOREs that, making it a no-op.
	#     => UPDATE finds the entry and modifies it.
	# (2) There is no entry for 'name'.
	#     => INSERT creates the entry.
	#     => UPDATE changes the entry to the same value, a no-op.
	$db eval {
	    INSERT OR IGNORE INTO global_config
	    VALUES (:name, :value);

	    UPDATE global_config
	    SET   value = :value
	    WHERE name  = :name
	}
    }
    return
}

proc ::fx::config::unset-local {db name} {
    $db transaction {
	$db eval {
	    DELETE
	    FROM config
	    WHERE name  = :name
	}
    }
    return
}

proc ::fx::config::unset-global {name} {
    ::set db [fossil global]
    $db transaction {
	$db eval {
	    DELETE
	    FROM global_config
	    WHERE name  = :name
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::mgr::config 0
return
