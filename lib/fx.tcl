#!/usr/bin/env tclsh
## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx ?
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta require     sqlite3
# Meta require     cmdr
# Meta require     {Tcl 8.5-}
# Meta require     lambda
# Meta require     fx::fossil
# Meta require     fx::config
# Meta require     fx::enum
## Meta require     fx::report
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require cmdr
package require lambda

# # ## ### ##### ######## ############# ######################

namespace eval fx {
    namespace export main
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc fx::main {argv} {
    try {
	fx do {*}$argv
    } trap {CMDR VALIDATE} {e o} {
	puts $e
    } on error {e o} {
	puts $::errorInfo
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc fx::call {p args} {
    lambda {p args} {
	package require fx::$p
	fx::$p {*}$args
    } $p {*}$args
}

proc fx::vt {p args} {
    lambda {p args} {
	package require fx::validate::$p
	fx::validate::$p {*}$args
    } $p {*}$args
}

# # ## ### ##### ######## ############# ######################

cmdr create fx::fx fx {
    common *all* {
	option repository {
	    The repository to work with.
	    Defaults to the repository of the
	    checkout we are in.
	} {
	    alias R
	    validate rwfile
	    generate [fx::call fossil locate]
	}
	state repository-db {
	    The repository database to work with.
	} {
	    defered
	    generate [fx::call fossil repository]
	}
    }

    private repository {
	section Introspection
	description {
	    Print the name of the repository we are working on.
	}
    } [lambda config {
	puts [$config @repository]
    }]

    # Configuration Mgmt. In all separate parts
    officer config {
	description {
	    Management of a fossil repositories' configuration, in detail.
	}
	common .setting {
	    input setting {
		The name of the configuration setting to work with.
	    } {
		validate [fx::vt setting]
	    }
	}

	private available {
	    section Configuration
	    description {
		List all available configuration settings.
	    }
	} [fx::call config available]

	private list {
	    section Configuration
	    description {
		List all changed configuration settings of the
		repository, and their values.
	    }
	} [fx::call config list]
	default

	private get {
	    section Configuration
	    description {
		Print the value of the named configuration setting.
	    }
	    use .setting
	} [fx::call config get]

	private set {
	    section Configuration
	    description {
		Change the value of the named
		configuration setting to the
		given text.
	    }
	    use .setting
	    input value {
		The new value of the configuration setting.
	    } {
	    }
	} [fx::call config set]

	private unset {
	    section Configuration
	    description {
		Remove the specified local configuration setting.
		This sets it back to the system default.
	    }
	    use .setting
	} [fx::call config unset]

	# Standard fossil cli configuration commands, implement maybe.
	# push
	# pull
	# sync
	# merge
	# export
	# import
	# reset
    }
    officer report {
	description {
	    Management of a fossil repositories' set of ticket reports.
	}

	private list {
	    section Reporting
	    description {
		List all reports defined in the repository.
	    }
	} [fx::call report list]
	default

	private def {
	    section Reporting
	    description {
		Add a report definition to the repository.
	    }
	    # ... ?owner?, title, (cols, sql)
	    option owner {
		Owner of the report.
		Defaults to the unix user running the command.
	    } {
		validate str
		default [lambda p { set ::tcl_platform(user) }]
	    }
	    input title {
		Report title.
	    } {
		validate str
	    }
	    input spec {
		Report specification.
		Defaults to reading it from stdin.
	    } {
		optional
		validate str
		generate [lambda p { read stdin }]
	    }
	} [fx::call report def]

	private get {
	    section Reporting
	    description {
		Retrieve the specified report definition.
	    }
	    input id {
		Id of the report to retrieve.
	    } {
		validate [fx::vt report-id]
	    }
	} [fx::call report get]
    }
    officer enum {
	description {
	    Management of enumerations for the ticketing system.
	}
	common .enum {
	    input enum {
		Name of the enumeration to operate on.
	    } {
		validate [fx::vt enum]
	    }
	}

	private list {
	    section Enumerations
	    description {
		List all enumerations stored in the repository.
	    }
	} [fx::call enum list]
	default

	private create {
	    section Enumerations
	    description {
		Create a new named enumeration.
	    }
	    input newenum {
		Name of the enumeration to create.
	    } {
		validate [fx::vt not-enum]
	    }
	    input items {
		Initial items of the new enumeration.
	    } {
		optional
		list
		validate str
	    }
	} [fx::call enum create]

	private delete {
	    section Enumerations
	    description {
		Delete the named enumeration. Careful, you may break your
		ticketing system. Check first that the enumeration is not
		used anymore.
	    }
	    use .enum
	} [fx::call enum delete]

	private export {
	    section Enumerations
	    description {
		Save the specified enumeration(s).
		Defaults to all.
	    }
	    option output {
		The file to save the enumeration(s) into.
		Defaults to stdout.
	    } {
		alias o
		validate wchan
	    }
	    input enums {
		Names of the enumerations to export.
	    } {
		optional
		list
		validate [fx::vt enum]
		generate [fx::vt enum default]
	    }
	} [fx::call enum export]

	private import {
	    section Enumerations
	    description {
		Import an enumeration from a save file.
	    }
	    input import {
		The file to read the enumeration from.
		Defaults to stdin.
	    } {
		optional
		validate rchan ;# cmdr - *file => *chan, default: stdin
	    }
	} [fx::call enum import]

	private add {
	    section Enumerations
	    description {
		Extend the specified enumeration with the given items.
	    }
	    use .enum
	    input items {
		Additional items of the enumeration.
	    } {
		list
		validate [fx::vt not-enum-item]
	    }
	} [fx::call enum add]

	private remove {
	    section Enumerations
	    description {
		Remove the named item(s) from the specified enumeration.
		Careful, you may break your ticketing system. Check
		first that the item is not used anymore.
	    }
	    use .enum
	    input items {
		Items of the enumeration to remove.
	    } {
		list
		validate [fx::vt enum-item]
	    }
	} [fx::call enum remove]

	private change {
	    section Enumerations
	    description {
		Rename the item in the specified enumeration.
		Careful, you may break your ticketing system. Check
		first that all users have made the same substitution.
	    }
	    use .enum
	    input item {
		Item of the enumeration to change.
	    } {
		validate [fx::vt enum-item]
	    }
	    input newitem {
		New name of the item in the enumeration.
	    } {
		validate [fx::vt not-enum-item]
	    }
	} [fx::call enum change]
    }
    # - mgmt of mirrors, fossil and git (export)
    # - mgmt of watchers
    # - Delegate unknown commands to fossil itself.
}

# # ## ### ##### ######## ############# ######################
package provide fx 0
return
