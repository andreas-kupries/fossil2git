#!/usr/bin/env tclsh
## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Application fx ?
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
package require sqlite3
package require cmdr
package require lambda

# During development direct link to the local packages
#lappend auto_path [file dirname [file normalize [info script]]]/lib

# # ## ### ##### ######## ############# ######################

cmdr create fx fx {
    common *all* {
	option repository {
	    The repository to work with.
	    Defaults to the repository of the
	    checkout we are in.
	} {
	    alias R
	    validate rwfile
	    generate [call fx::fossil locate]
	}
	state repository-db {
	    The repository database to work with.
	} {
	    defered
	    generate [call fx::fossil repository]
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
		validate [call fx::config setting]
	    }
	}

	private available {
	    section Configuration
	    description {
		List all available configuration settings.
	    }
	} [call fx::config available]

	private list {
	    section Configuration
	    description {
		List all changed configuration settings of the
		repository, and their values.
	    }
	} [call fx::config list]
	default

	private get {
	    section Configuration
	    description {
		Print the value of the named configuration setting.
	    }
	    use .setting
	} [call fx::config get]

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
	} [call fx::config set]

	private unset {
	    section Configuration
	    description {
		Remove the specified local configuration setting.
		This sets it back to the system default.
	    }
	    use .setting
	} [call fx::config unset]

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
	} [call fx::report list]
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
	} [call fx::report def]

	private get {
	    section Reporting
	    description {
		Retrieve the specified report definition.
	    }
	    input id {
		Id of the report to retrieve.
	    } {
		validate [call fx::report id]
	    }
	} [call fx::report get]
    }
    officer enum {
	description {
	    Management of value enumeration for the ticketing system.
	}

	common .enum {
	    input enum {
		Name of the enumeration to operate on.
	    } {
		validate [call fx::enum known]
	    }
	}
	common .enumvalue {
	    input item {
		Value of the enumeration to operate on.
	    } {
		validate [call fx::enum item]
	    }
	}
	common .newenumvalue {
	    input newitem {
		New value for the enumeration.
	    } {
		validate [call fx::enum notitem]
	    }
	}

	private list {
	    section Enumerations
	    description {
		List all enumerations stored in the repository.
	    }
	} [call fx::enum list]
	default

	private create {
	    section Enumerations
	    description {
		Create a new named enumeration.
	    }
	    input newenum {
		Name of the enumeration to create.
	    } {
		validate [call fx::enum notknown]
	    }
	    input values {
		Initial values of the new enumeration.
	    } {
		optional ; list ; validate str
	    }
	} [call fx::enum create]

	private delete {
	    section Enumerations
	    description {
		Delete the named enumeration. Careful, you may break your
		ticketing system. Check first that the enumeration is not
		used anymore.
	    }
	    use .enum
	} [call fx::enum delete]

	private export {
	    section Enumerations
	    description {
		Save the specified enumeration.
	    }
	    use .enum
	    input export {
		The file to save the enumeration into.
		Defaults to stdout.
	    } {
		optional
		validate wchan ;# cmdr - *file => *chan, default: stdout
	    }
	} [call fx::enum export]

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
	} [call fx::enum import]

	private add {
	    section Enumerations
	    description {
		Extend the specified enumeration with the named value.
	    }
	    use .enum
	    use .newenumvalue
	} [call fx::enum add]

	private remove {
	    section Enumerations
	    description {
		Remove the named value from the specified enumeration.
		Careful, you may break your ticketing system. Check
		first that the value is not used anymore.
	    }
	    use .enum
	    use .enumvalue
	} [call fx::enum remove]

	private change {
	    section Enumerations
	    description {
		Rename the value in the specified enumeration.
		Careful, you may break your ticketing system. Check
		first that all users have made the same substitution.
	    }
	    use .enum
	    use .enumvalue
	    use .newenumvalue
	} [call fx::enum change]
    }
    # - mgmt of mirrors, fossil and git (export)
    # - mgmt of watchers
    # - Delegate unknown commands to fossil itself.
}

proc main {} {
    global argv

    try {
	fx do {*}$argv
    } trap {CMDR VALIDATE} {e o} {
	puts $e
    } on error {e o} {
	puts $o
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc call {p args} {
    lambda {p args} {
	package require $p
	$p {*}$args
    } $p {*}$args
}

# # ## ### ##### ######## ############# ######################

main
exit
