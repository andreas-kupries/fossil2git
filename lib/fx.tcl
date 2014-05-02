#!/usr/bin/env tclsh
## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx ?
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
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
package require debug
package require debug::caller
package require lambda
package require fx::color ; # color activation
package require fx::seen  ; # set-progress
package require fx::tty   ; # stdout check

# # ## ### ##### ######## ############# ######################

if {[fx tty stdout]} {
    fx color activate
}

debug level  fx
debug prefix fx {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval fx {
    namespace export main
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## TODO: enable command history.

proc ::fx::main {argv} {
    debug.fx {}
    try {
	fx do {*}$argv
    } trap {CMDR CONFIG WRONG-ARGS} {e o} - \
      trap {CMDR CONFIG BAD OPTION} {e o} - \
      trap {CMDR VALIDATE} {e o} - \
      trap {CMDR ACTION UNKNOWN} {e o} - \
      trap {CMDR ACTION BAD} {e o} - \
      trap {CMDR VALIDATE} {e o} - \
      trap {CMDR PARAMETER LOCKED} {e o} - \
      trap {CMDR DO UNKNOWN} {e o} {
	debug.fx {trap - cmdline user error}
	puts stderr "$::argv0 cmdr: [color error $e]"
	return 1

    } trap {FX} {e o} {
	debug.fx {trap - other user error}
	puts stderr "$::argv0 general: [color error $e]"
	return 1
	
    } on error {e o} {
	debug.fx {trap - general, internal error}
	debug.fx {[debug pdict $o]}
	# TODO: nicer formatting of internal errors.
	puts stderr [color error $::errorInfo]
	mail-error $::errorInfo
	return 1
    }

    debug.fx {done, ok}
    return 0
}

proc ::fx::mail-error {e} {
    package require fx::mailer
    package require fx::mailgen
    set config [::fx mailer get-config]
    set admin  [lindex [dict get $config -header] end]

    ::fx mailer send $config $admin \
	[::fx mailgen for-error $e] on
    return
}

# # ## ### ##### ######## ############# ######################
## Support commands constructing glue for various callbacks.

proc ::fx::call {p args} {
    lambda {p args} {
	package require fx::$p
	fx::$p {*}$args
    } $p {*}$args
}

proc ::fx::vt {p args} {
    lambda {p args} {
	package require fx::validate::$p
	fx::validate::$p {*}$args
    } $p {*}$args
}

proc ::fx::exclude {locked} {
    # Jump into the context of the parameter instance currently
    # getting configured. At the time the spec is executed things
    # regarding naming are in good enough shape to extract naming
    # information. While aliases for options are missing these are of
    # no relevance to our purpose here either, we need only the
    # primary name, and that is initialized by now.

    set by [uplevel 2 {my the-name}]
    lambda {locked by p args} {
	#debug.cmdr {}
	$p config @$locked lock $by
    } $locked $by
}

proc ::fx::overlay {path args} {
    set cmd {}
    if {[llength $args]} {
	set cmd " '[join $args { }]'"
    }
    [::fx::fx find $path] learn [subst {
	private delegate {
	    section Convenience
	    description {
		Delegate the command$cmd to the local fossil executable.
	    }
	    input args {
		Command and arguments to deliver to core fossil
	    } { list ; validate str }
	} {fx::delegate {$args}}
	# All commands not known to fx at this level are delegated to
	# the core fossil application.
	default
    }]
}

proc ::fx::delegate {prefix config} {
    # Any issues of the command delegated to are its problems, and not ours.
    # It will have them reported already anyway as well.
    catch {
	exec >@ stdout 2>@ stderr <@ stdin \
	    {*}[auto_execok fossil] {*}$prefix {*}[$config @args]
    }
}

# # ## ### ##### ######## ############# ######################

fx seen set-progress [lambda {text} {
    set eeol \033\[K
    puts -nonewline \r$eeol\r$text
    flush stdout
}]

# # ## ### ##### ######## ############# ######################

cmdr create fx::fx [file tail $::argv0] {
    # # ## ### ##### ######## ############# ######################
    ## Common pieces across the various commands.

    common .repository {
	option repository {
	    The repository to work with. Defaults to the repository of
	    the checkout we are in, or, outside of a checkout, the
	    explicitly configured "default" repository.
	} {
	    alias R
	    validate rwfile
	    generate [fx::call fossil repository-find]
	    # Note: This generator command dynamically recognizes
	    # commands with an "all" parameter, and disables itself
	    # (*) if that parameter is active/set.
	    # (Ad *): I.e. returns an empty string.
	    # See also .no-search
	}
	state repository-db {
	    The repository database we are working with.
	} {
	    immediate
	    # Ensures that this is run before the action code, making
	    # the database command globally accessible.
	    generate [fx::call fossil repository-open]
	}
    }

    common *all* {
	option debug {
	    Placeholder. Processed before reaching cmdr.
	} {
	    undocumented
	    validate str
	}
	option color {
	    Force the (non-)use of colors in the output. The default
	    depends on the environment, active when talking to a tty,
	    and otherwise not.
	} {
	    when-set [lambda {p x} {
		fx color activate $x
	    }]
	}
	use .repository
    }

    common .global {
	# Used by officers 'config' and 'note config'.
	option global {
	    Operate on the global configuration.
	} { alias G ; presence }
    }

    common .global-local {
	# Used by officers 'config' and 'note config'.
	option global {
	    Operate on the global configuration.
	} {
	    alias G ; presence
	    ::fx::exclude local
	}
	option local {
	    Operate strictly on the local configuration.
	} {
	    alias L ; presence
	    ::fx::exclude global
	}
    }

    common .extend {
	# Used by officer'note config'.
	option extend {
	    Extend the current tables.
	} { presence }
    }

    common .uuid {
	input uuid {
	    Full fossil uuid of the artifact to work with.
	} { validate [fx::vt uuid] }
    }

    common .all {
	option all {
	    Do this for all repositories watched by fx.
	} { alias A; presence }
	# See also the note in option repository above.
    }

    common .verbose {
	option verbose {
	    Activate more chatter.
	} { alias v; presence }
    }

    common .uuid-or-all {
	input uuid {
	    Full fossil uuid of the artifact to work with.
	} {
	    optional
	    validate [fx::vt uuid]
	    when-set [fx::exclude overall]
	}
	option overall {
	    Do this for all repositories watched by fx.
	} {
	    label all
	    alias A
	    presence
	    when-set [fx::exclude uuid]
	}
	state uuid-all-check {
	    Check that either uuid or --all were used.
	    The exclusion have already made sure that not both are set.
	} {
	    immediate
	    when-complete [lambda {p x} {
		if {[$p config @uuid    set?] ||
		    [$p config @overall set?]} return
		return -code error -errorcode {CMDR VALIDATE} \
		    "Must use either uuid or --all" 
	    }]
	}
    }

    common .export {
	input output {
	    The path of the file to save the exported data into.
	} {
	    validate wchan
	}
    }

    common .import {
	input input {
	    The path of the file to read the data from.
	    Defaults to stdin.
	} {
	    optional
	    validate rchan
	}
    }

    # # ## ### ##### ######## ############# ######################

    common .event-hidden-validation {
	state event {
	    Hidden parameter to be used by the internal validation of
	    event-types.
	} {
	    label imported-event
	    validate [fx::vt event-type]
	}
    }
    common .field-hidden-validation {
	state field {
	    Hidden parameter to be used by the internal validation of
	    ticket fields.
	} {
	    label imported-ticket-field
	    validate [fx::vt ticket-field]
	}
    }
    common .mailconfig-hidden-validation {
	state mailconfig {
	    Hidden parameter to be used by the internal validation of
	    mail configuration keys
	} {
	    label imported-mail-config-key
	    validate [fx::vt mail-config]
	}
    }
    common .mailaddr-hidden-validation {
	state mailaddr {
	    Hidden parameter to be used by the internal validation of
	    email addresses.
	} {
	    label imported-mail-address
	    validate [fx::vt mail-address]
	}
    }
    common .routemap {
	# All validation fields used by the RouteMap code.
	use .field-hidden-validation
	use .event-hidden-validation
	use .mailaddr-hidden-validation
    }
    common .no-search {
	state no-search {
	    Fake parameter to disable repository search by its mere
	    presence.
	} {}
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

    private save {
	description {
	    Save all fx-managed state of the repository.
	}
	use .export
    } [fx::call state save]

    private restore {
	description {
	    Load all fx-managed state of a repository.
	}
	use .import
    } [fx::call state restore]

    officer repository {
	description {
	    Manage the repository to work with.
	}

	private show {
	    section Introspection
	    section {Repository Management}
	    description {
		Print the name of the repository we are working on, if any.
	    }
	} [fx::call fossil c_show_repository]
	default

	private default {
	    section Introspection
	    section {Repository Management}
	    description {
		Print the name of the default repository, if any.
	    }
	    use .no-search
	} [fx::call fossil c_default_repository]

	private reset {
	    section {Repository Management}
	    description {
		Unset the current default repository.
	    }
	    use .no-search
	} [fx::call fossil c_reset_repository]

	private set {
	    section {Repository Management}
	    description {
		Set the path to the current default repository.
	    }
	    use .no-search
	    input target {
		The path to the current repository to use when all else fails.
	    } {
		validate rwpath
	    }
	} [fx::call fossil c_set_repository]
    }

    # # ## ### ##### ######## ############# ######################
    ## Overlay to the standard "fossil user" command

    officer user {
	description {
	    Management of users in the local repository
	}

	private push {
	    section {User Management}
	    description {
		Push local changes to the users to the
		configured remote
	    }
	} [fx::call user push]

	private pull {
	    section {User Management}
	    description {
		Push user information from the
		configured remote to here.
	    }
	} [fx::call user pull]

	private sync {
	    section {User Management}
	    description {
		Sync the user information at the configured
		remote and here.
	    }
	} [fx::call user sync]

	private list {
	    section {User Management}
	    description {
		Show all known users, their information and capabilities
	    }
	} [fx::call user list]

	private broadcast {
	    section {User Management}
	    description {
		Send a mail to all accounts of the repository.
	    }
	    input text {
		The file containing the contents of the mail.
		Defaults to stdin
	    } {
		optional
		validate rchan
	    }
	} [fx::call user broadcast]

	private contact {
	    section {User Management}
	    description {
		Change the contact information for the named user
	    }
	    input user {
		The name of the user to update.
	    } {
		validate [fx::vt user]
		# need extended interaction ops => part of cmdr ?
		#generate [fx::call user select-for {contact change}]
	    }
	    input contact {
		The new contact information of the user.
		Will be asked for interactively if not specified.
	    } {
		optional
		validate str
		interact
	    }
	} [fx::call user update-contact]
    }

    # # ## ### ##### ######## ############# ######################
    ## Extended configuration management.

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
	common .setting-list {
	    input setting {
		The names of the configuration settings to work with.
	    } {
		list
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
	    } {}
	} [fx::call config set]

	private unset {
	    section Configuration
	    description {
		Remove the specified local configuration setting.
		This sets it back to the system default.
	    }
	    use .setting-list
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
    ## Report management. Using an external report format which is
    ## easier to write by a human being. Also nicer table output, and
    ## structured output.

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
    ## Management of enumerations (used both internally and by the
    ## ticket system, for example. Type, severity, priority, category,
    ## ...)

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
	    use .export
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
	    use .import
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

	private items {
	    section Enumerations
	    description {
		Show the items in the specified enumeration.
	    }
	    use .enum
	} [fx::call enum items]
    }

    alias enums = enum list

    # # ## ### ##### ######## ############# ######################
    ## Change notifications, management and generation.

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

	officer config {
	    description {
		Manage the mail setup for notification emails.
	    }

	    common .key {
		input key {
		    The part of the mail setup to (re)configure.
		} { validate [fx::vt mail-config] }
	    }

	    common .key-list {
		input key {
		    The parts of the mail setup to unset.
		} { list ; validate [fx::vt mail-config] }
	    }

	    private show {
		section Notifications {Mail setup}
		section Introspection
		description {
		    Show the current mail setup for notifications.
		}
		use .global-local
	    } [fx::call note mail-config-show]
	    default

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
		use .key-list
	    } [fx::call note mail-config-unset]

	    private reset {
		section Notifications {Mail setup}
		description {
		    Reset all parts of the mail setup for notifications
		    to their defaults.
		}
		use .global
	    } [fx::call note mail-config-reset]

	    private export {
		section Notifications {Mail setup}
		description {
		    Save the notification configuration into a file.
		}
		use .global-local
		use .export
	    } [fx::call note mail-config-export]

	    private import {
		section Notifications {Mail setup}
		description {
		    Import the notification configuration from a save file.
		}
		use .global
		use .import
		use .mailconfig-hidden-validation
	    } [fx::call note mail-config-import]
	}

	private update-history {
	    section Notifications Control
	    description {
		Update the cached ticket history used to calculate
		dynamic routes.
	    }
	    option clear {
		Clear the ticket history before updating. I.e. force
		full update from scratch, instead of doing an
		incremental one.

	    } { presence }
	} [fx::call seen regenerate-series]

	private watched {
	    section Notifications Control
	    description {
		Show the list of repositories currently watched
		(i.e. those which have active routes). These fall
		under the purview of 'note deliver --all'.
	    }
	    use .no-search
	} [fx::call note watched]

	# TODO: Global routes?
	officer route {
	    private list {
		section Notifications Destinations
		section Introspection
		description {
		    Show all configured mail destinations (per event type).
		}
		use .routemap
	    } [fx::call note route-list]
	    default

	    private export {
		section Notifications Destinations
		description {
		    Save the configured mail destinations into a file.
		}
		use .export
		use .routemap
	    } [fx::call note route-export]

	    private import {
		section Notifications Destinations
		description {
		    Import mail destinations from a save file.
		}
		use .extend
		use .import
		use .routemap
	    } [fx::call note route-import]

	    common .etype {
		input event {
		    Event to work with.
		} { validate [fx::vt event-xtype] }
	    }

	    private add {
		section Notifications Destinations
		description {
		    Add fixed mail destination for the named event type.
		}
		use .etype
		input to {
		    Email addresses of the added routes.
		} {
		    list
		    validate [fx::vt mail-address]
		}
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
		section Introspection
		description {
		    Show all events we can generate notifications for.
		}
	    } [fx::call note event-list]

	    officer field {
		private list {
		    section Notifications Destinations
		    section Introspection
		    description {
			Show all available ticket fields (for dynamic routes).
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
	    use .routemap
	    use .verbose
	} [fx::call note deliver]

	private mark-pending {
	    section Notifications Control
	    description {
		Mark the specified (or all) artifacts as having not
		been notified before. This forces the generation of a
		notification for them on the next invokation of
		"note deliver".
	    }
	    use .uuid-or-all
	} [fx::call note mark-pending]

	private mark-notified {
	    section Notifications Control
	    description {
		Mark the specified (or all) artifacts as having been
		notified before, thus preventing generation of a
		notification for them on the next invokation of
		"note deliver".
	    }
	    use .uuid-or-all
	} [fx::call note mark-notified]

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

	private mail-address {
	    section Testing
	    description {
		Parse the specified address into parts, and determine
		if it is lexically ok for us, or not, and why not in
		case of the latter.
	    }
	    input address {
		The address to parse and test.
	    } { }
	} [fx::call mailer test-address]

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
	    use .uuid-or-all
	} [fx::call note test-mail-gen]

	private mail-receivers {
	    section Testing
	    description {
		Analyse the specified artifact and determine the set
		of mail addresses to send a notification to, fixed
		and field-based.
	    }
	    use .uuid-or-all
	    use .routemap
	} [fx::call note test-mail-receivers]

	private manifest-parse {
	    section Testing
	    description {
		Parse the specified artifact as manifest and print the
		resulting array/dictionary to stdout.
	    }
	    use .uuid-or-all
	} [fx::call note test-parse]

	private tags {
	    section Testing
	    description {
		Determine the names, types, and values of all tags
		associated with a checkin.
	    }
	    use .uuid
	} [fx::call fossil test-tags]

	private branch {
	    section Testing
	    description {
		Determine the branch of a checkin.
	    }
	    use .uuid
	} [fx::call fossil test-branch]
    }

    officer debug {
	description {
	    Various commands to help debugging the system itself
	    and its configuration.
	}

	private levels {
	    section Debugging
	    description {
		List all debug levels known to the system,
		we can enable for narrative
	    }
	} [fx::call debug levels]
    }

    # Shortcut
    alias ticket-fields = note route field list
    # aka                 note route fields

    # TODO - mgmt of mirrors, fossil and git (export)
}

# # ## ### ##### ######## ############# ######################
## Add delegations.

fx::overlay {}
fx::overlay user user

# # ## ### ##### ######## ############# ######################
package provide fx 0
return
