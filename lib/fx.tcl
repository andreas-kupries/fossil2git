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

cmdr create fx::fx $::argv0 {
    # # ## ### ##### ######## ############# ######################
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

    common .global {
	# Used by officers 'config' and 'note config'.
	option global {
	    Set the configuration globally
	} { alias g ; presence }
    }

    # # ## ### ##### ######## ############# ######################
    private repository {
	section Introspection
	description {
	    Print the name of the repository we are working on.
	}
    } [lambda config {
	puts [$config @repository]
    }]

    private delegate {
	section Convenience
	description {
	    Delegate the command to the local fossil executable.
	}
	input args {
	    Command and arguments to deliver to core fossil
	} { list ; validate str }
    } [lambda config {
	exec >@ stdout 2>@ stderr <@ stdin \
	    {*}[auto_execok fossil] {*}[$config @args]
    }]
    # All commands not known to fx are delegated to the fossil core.
    default

    # # ## ### ##### ######## ############# ######################
    officer config {
	description {
	    Management of a fossil repositories' configuration, in detail.
	    I.e. this has access to all the individual pieces.
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

    # # ## ### ##### ######## ############# ######################
    # Report mgmt. Using an external report format which is easier to
    # write by a human being. Also nicer table output, and structured
    # output.
    officer report {
	description {
	    Management of a fossil repositories' set of ticket reports.
	}

	# execute a report ... proper matrix output, json output, nested tcl
	# execute a temp report => enter a report, execute it, delete it.
	# see if we can get reports parameterized. at least from fx.

	private list {
	    section Reporting
	    description {
		List all reports defined in the repository.
	    }
	} [fx::call report list]
	default

	private add {
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
		The report's name.
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
	} [fx::call report add]

	private get {
	    section Reporting
	    description {
		Retrieve the specified report definition.
	    }
	    input id {
		Id or name of the report to retrieve.
	    } {
		validate [fx::vt report-id]
	    }
	} [fx::call report get]

	private delete {
	    section Reporting
	    description {
		Delete the specified report definition.
	    }
	    input id {
		Id or name of the report to delete.
	    } {
		validate [fx::vt report-id]
	    }
	} [fx::call report delete]
    }

    # # ## ### ##### ######## ############# ######################
    # Mgmt of enumerations (used in ticket system for example. Type,
    # severity, priority, category, ...)
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

    # # ## ### ##### ######## ############# ######################
    officer note {
	description {
	    Management of notification emails for ticket
	    changes, new revisions, etc.
	}

	# Required commands:
	# - Global setup (mail configuration)
	# - Show and change the mail configuration
	# - Add/remove fixed mail receivers (per event type)
	# - Config of dynamic ticket receivers
	#   => ticket fields to use as sources
	#   ex. Tcl/Tk: assignee, closer, login, contact, submitter
	# - TODO-SPEC Exclude/Include users from email delivery
	# - TODO-SPEC Suspend/activate notification for a project, event type.
	# - MAYBE watch remote repo (ping /stat) => create a local clone, watch implies sync.
	#
	# All commands check for and remind the user about a missing
	# mail configuration, especially the mandatory fields.

	# Old command set (see bin/)
	#
	# init              | irrelevant, dropped
	# final             | irrelevant, dropped
	# cron              | ?

	# setup   repo from | automatic, 'from' handling moves to mail setup below.
	# destroy repo      | irrelevant, dropped

	# config-get ?k?    | config show  (--global, -G)
	# config-set k v    | config set
	# config-unset k    | config unset

	# add    repo to    | route add type to
	# list   repo       | route list, routes
	# remove repo to    | route drop type ?to?
	#                   | route field add  to | type 't' implied.
	#                   | route field drop to |
	# do                | deliver ?--global?

	# expire            | irrelevant, dropped
	# rss               | irrelevant, dropped
	# dump  uuid        | 'fossil artifact'
	# unsee uuid        | as-is

	officer config {
	    description {
		Manage the mail setup for notification emails.
	    }
	    private show {
		section Notifications {Mail setup}
		description {
		    Show the current mail setup for notifications.
		}
	    } [fx::call note mail-config-show]
	    default

	    common .key {
		input key {
		    The part of the mail setup to (re)configure.
		} { validate [fx::vt mail-config]
		}
	    }
	    private set {
		section Notifications {Mail setup}
		description {
		    Set the specified part of the mail setup for notifications.
		}
		use .global
		use .key
		input value {
		    The new value of the configuration.
		}
	    } [fx::call note mail-config-set]

	    private unset {
		section Notifications {Mail setup}
		description {
		    Reset the specified part of the mail setup for notifications
		    to its default.
		}
		use .global
		use .key
	    } [fx::call note mail-config-unset]
	}

	officer route {
	    private list {
		section Notifications
		description {
		    Show all mail destinations.
		}
	    } [fx::call note route-list]
	    default

	    common .etype {
		input event {
		    Event to work with.
		} { validate [fx::vt event-type] }
	    }

	    private add {
		section Notifications
		description {
		    Add fixed mail destination for the named event type.
		}
		use .etype
		input to {
		    Email addresses of the added routes.
		} { list ; validate str }
	    } [fx::call note route-add]

	    private drop {
		section Notifications
		description {
		    Remove the specified mail destinations
		    (glob pattern) for the event type.
		}
		use .etype
		input to {
		    Glob patterns of the emails to remove
		    from the routes.
		} {
		    optional
		    list
		    default *
		    validate str
		}
	    } [fx::call note route-drop]

	    officer field {
		private list {
		    section Notifications
		    description {
			Show all available ticket fields.
		    }
		} [fx::call note field-list]
		default

		private add {
		    section Notifications
		    description {
			Add field as source of mail destinations for ticket events.
		    }
		    input field {
			Name of the field to use as source of mail destinations.
		    } {
			list
			validate [fx::vt ticket-field]
		    }
		} [fx::call note route-field-add]

		private drop {
		    section Notifications
		    description {
			Remove the specified field as source
			of mail destinations for ticket events.
		    }
		    input field {
			Name of the field to stop using as source of mail destinations.
		    } {
			list
			validate [fx::vt ticket-field]
		    }
		} [fx::call note route-field-drop]
	    }
	    alias fields = field list
	}
	alias routes = route list

	private deliver {
	    section Notifications
	    description {
		Send notification emails to all configured destinations,
		for all new events (since the last delievery).
	    }
	    use .global
	    # or .all ?
	} [fx::call note deliver]
    }

    # - mgmt of mirrors, fossil and git (export)
    # - Delegate unknown commands to fossil itself.
}

# # ## ### ##### ######## ############# ######################
package provide fx 0
return
