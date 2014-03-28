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
    } trap {CMDR CONFIG WRONG-ARGS} {e o} - \
      trap {CMDR VALIDATE} {e o} {
        puts $e
	return 1
    } on error {e o} {
	puts $::errorInfo
	return 1
    }
    return 0
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

cmdr create fx::fx [file tail $::argv0] {
    # # ## ### ##### ######## ############# ######################
    common *all* {
	option repository {
	    The repository to work with.
	    Defaults to the repository of the
	    checkout we are in.
	} {
	    alias R
	    validate rwfile
	    generate [fx::call fossil repository-find]
	    # Note: This generator command dynamically recognizes
	    # commands with an "all" parameter, and disables itself
	    # (*) if that parameter is active/set. Ad *: I.e. returns
	    # an empty string.
	}
	state repository-db {
	    The repository database we are working with.
	} {
	    # ensure that this is run before the action code, making
	    # the database command globally accessible.
	    immediate
	    generate [fx::call fossil repository-open]
	}
    }

    common .global {
	# Used by officers 'config' and 'note config'.
	option global {
	    Set the configuration globally
	} { alias g ; presence }
    }

    common .all {
	option all {
	    Do this for all repositories watched by fx.
	} { alias A; presence }
	# See also the note in option repository above.
    }

    # # ## ### ##### ######## ############# ######################

    private version {
	section Introspection
	description {
	    Print version and revision of the application.
	}
    } [lambda config {
	puts "[file tail $::argv0] [package present fx]"
    }]

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

    # TODO Helper: Show generated mail
    # TODO Helper: Test sending a mail

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
	# - TODO-SPEC Exclude/Include users from email delivery
	# - TODO-SPEC Suspend/activate notification for a project, event type.
	# - MAYBE watch remote repo (ping /stat) => create a local clone,
	#                                             watch implies sync.
	#
	# All commands check for and remind the user about a missing
	# mail configuration, especially the mandatory fields.

	# dump  uuid        | 'fossil artifact'
	# unsee uuid        | test touch(-all)
	#                   |
	#                   | test mail-setup
	#                   | test manifest-parse uuid
	#                   | test mail-for       uuid
	#                   | test mail-receivers uuid

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

	# TODO: Batch export/import of routes.
	# TODO: Global routes?

	officer route {
	    private list {
		section Notifications Destinations
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
		section Notifications Destinations
		description {
		    Add fixed mail destination for the named event type.
		}
		use .etype
		input to {
		    Email addresses of the added routes.
		} { list ; validate str }
	    } [fx::call note route-add]

	    private drop {
		section Notifications Destinations
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

	    private events {
		section Notifications Destinations
		description {
		    Show all events we can generate notifications for.
		}
	    } [fx::call note event-list]

	    officer field {
		private list {
		    section Notifications Destinations
		    description {
			Show all available ticket fields.
		    }
		} [fx::call note field-list]
		default

		private add {
		    section Notifications Destinations
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
		    section Notifications Destinations
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
		for all new events (since the last delivery).
	    }
	    use .all
	} [fx::call note deliver]

	private mark-pending {
	    section Notifications Control
	    description {
		Mark the specified artifact as having not been notified before,
		thus forcing the generation of a notification for it on the next
		invokation of "deliver".
	    }
	    input uuid {
		Fossil id of the artifact to touch.
	    } {
		#validate [fx::vt uuid] -- TODO
	    }
	} [fx::call note mark-pending]

	private mark-notified {
	    section Notifications Control
	    description {
		Mark the specified artifact as having been notified before, thus
		preventing generation of a notification for it on the next
		invokation of "deliver".
	    }
	    input uuid {
		Fossil id of the artifact to hide.
	    } {
		#validate [fx::vt uuid] -- TODO
	    }
	} [fx::call note mark-notified]

	private mark-pending-all {
	    section Notifications Control
	    description {
		Mark all events in the timeline as requiring a notification.
	    }
	} [fx::call note mark-pending-all]

	private mark-notified-all {
	    section Notifications Control
	    description {
		Mark all events in the timeline as not requiring a notification.
	    }
	} [fx::call note mark-notified-all]

	private show-pending {
	    section Notifications Control
	    description {
		Show all events in the timeline marked as pending.
	    }
	} [fx::call note show-pending]
    }

    officer test {
	description {
	    Various commands to test the system and its configuration.
	}


	# TODO: inverted operation: untouch|hide => prevent future notifications.

	private mail-setup {
	    section Testing
	    description {
		Generate a test mail and send it using the current
		mail configuration.
	    }
	    input destination {
		The destination address to send the test mail to.
	    } { }
	} [fx::call note test-mail-config]

	private mail-for {
	    section Testing
	    description {
		Generate the notification mail for the specified artifact,
		and print it to stdout.
	    }
	    input uuid {
		Fossil id of the artifact to generate the notification
		mail for.
	    } {
		#validate [fx::vt uuid] -- TODO
	    }
	} [fx::call note test-mail-gen]

	private mail-receivers {
	    section Testing
	    description {
		Analyse the specified artifact and determine the set
		of mail addresses to send a notification to, fixed
		and field-based.
	    }
	    input uuid {
		Fossil id of the artifact to inspect.
	    } {
		#validate [fx::vt uuid] -- TODO
	    }
	} [fx::call note test-mail-receivers]

	private manifest-parse {
	    section Testing
	    description {
		Parse the specified artifact as manifest and print the
		resulting array/dictionary to stdout.
	    }
	    input uuid {
		Fossil id of the artifact to parse.
	    } {
		#validate [fx::vt uuid] -- TODO
	    }
	} [fx::call note test-parse]
    }

    officer debug {
	undocumented
	description {
	    Various commands to help debugging the system and its configuration.
	}
    }

    # TODO - mgmt of mirrors, fossil and git (export)
}

# # ## ### ##### ######## ############# ######################
package provide fx 0
return
