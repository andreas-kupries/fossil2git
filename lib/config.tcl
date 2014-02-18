## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::config 0
# Meta author      ?
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require sqlite3
package require fx::fossil
package require fx::table
package require cmdr::validate::common

namespace eval ::fx::config {
    namespace export setting available list get set
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
    namespace import ::fx::table::do
    rename do table

    # Dictionary of configuration settings, mapping name to
    # specification consisting of its name in the database and a
    # boolean flag indicating if the user can change this setting.

    # Assumed database schema
    # Table "config"
    # Columns name  TEXT PK
    # Columns mtime DATE
    # Columns value CLOB

    #	ckout:*        - paths of known checkouts
    #	last-sync-pw   -|see 'f remote' command.
    #	last-sync-url  -|
    #	peer-*         -
    #	subrepo:*      -
    #	skin:*         - skin definitions
    #	baseurl:*      -

    # editable configset db-name default
    variable legal {
	aux-schema             {0 .	.}
	content-schema         {0 .	.}
	localauth              {0 .	.}
	project-code           {0 .	.}
	seen-delta-manifest    {1 .	.}
	server-code            {0 .	.}

	css                    {1 css 	.}
	header                 {1 skin	.}
	footer                 {1 skin	.}
	logo-mimetype          {1 skin	.}
	logo-image             {1 skin	.}
	background-mimetype    {1 skin	.}
	background-image       {1 skin	.}
	index-page             {1 skin	.}
	timeline-block-markup  {1 skin	.}
	timeline-max-comment   {1 skin	.}
	timeline-plaintext     {1 skin	.}
	adunit                 {1 skin	.}
	adunit-omit-if-admin   {1 skin	.}
	adunit-omit-if-user    {1 skin	.}

	th1-setup              {1 th1	.}
	th1-uri-regexp         {1 th1	.}
	tcl                    {1 th1	.}
	tcl-setup              {1 th1	.}

	project-name           {1 proj	.}
	short-project-name     {1 proj	.}
	project-description    {1 proj	.}
	manifest               {1 proj	.}
	binary-glob            {1 proj	.}
	clean-glob             {1 proj	.}
	ignore-glob            {1 proj	.}
	keep-glob              {1 proj	.}
	crnl-glob              {1 proj	.}
	encoding-glob          {1 proj	.}
	empty-dirs             {1 proj	.}
	allow-symlinks         {1 proj	.}

	ticket-table           {1 tkt 	.}
	ticket-common          {1 tkt 	.}
	ticket-change          {1 tkt 	.}
	ticket-newpage         {1 tkt 	.}
	ticket-viewpage        {1 tkt 	.}
	ticket-editpage        {1 tkt 	.}
	ticket-reportlist      {1 tkt 	.}
	ticket-report-template {1 tkt 	.}
	ticket-key-template    {1 tkt 	.}
	ticket-title-expr      {1 tkt 	.}
	ticket-closed-expr     {1 tkt 	.}

	xfer-common-script     {1 xfer	.}
	xfer-push-script       {1 xfer	.}
	xfer-commit-script     {1 xfer	.}
	xfer-ticket-script     {1 xfer	.}
    }
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal configuration settings

namespace eval ::fx::config::setting {
    namespace export release validate default complete
    namespace ensemble create
}

proc ::fx::config::setting::release  {p x} { return }
proc ::fx::config::setting::validate {p x} {
    variable ::fx::config::legal
    set cx [string tolower $x]
    if {$cx in [dict keys $legal]} { return $cx }
    fail $p SETTING "a configuration setting" $x
}

proc ::fx::config::setting::default  {p} { return {} }
proc ::fx::config::setting::complete {p} {
    variable ::fx::config::legal
    complete-enum list [dict keys $legal] $x
}

# # ## ### ##### ######## ############# ######################

proc ::fx::config::available {config} {
    variable legal
    puts [join [lsort -dict [dict keys $legal]] \n]
}

proc ::fx::config::list {config} {
    # TODO: order by name, or last-changed
    # Currently fixed order by name.

    [table t {Setting Last-Changed Value} {
	[$config @repository-db] eval {
	    SELECT name, value, datetime(mtime) AS modtime
	    FROM   config
	    ORDER BY name
	    ;
	} {
	    if {[string match ckout:*     $name]} continue
	    if {[string match peer-*      $name]} continue
	    if {[string match subrepo:*   $name]} continue
	    if {[string match skin:*      $name]} continue
	    if {[string match baseurl:*   $name]} continue
	    if {[string match last-sync-* $name]} continue

	    # Force unix EOL conventions.
	    ::set value [string map [::list \r\n \n \r \n] $value]

	    # Reduce multi-line values to their first line.
	    if {[string match *\n* $value]} {
		::set value [lindex [split $value \n] 0]...
	    }
	    # Restrict large values to their first 30 characters.
	    if {[string length $value] > 30} {
		::set value [string range $value 0 29]...
	    }

	    $t add $name $modtime $value
	}
    }] show puts
    return
}

proc ::fx::config::get {config} {
    ::set name [$config @setting]
    puts [[$config @repository-db] onecolumn {
	SELECT value
	FROM  config
	WHERE name  = :name
	;
    }]
    return
}

proc ::fx::config::set {config} {
    ::set name  [$config @setting]
    ::set value [$config @value]

    puts -nonewline "Setting ${name}: "

    [$config @repository-db] eval {
	UPDATE config
	SET   value = :value
	WHERE name  = :name
	;
    }

    puts " '$value'"
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::config 0
return
