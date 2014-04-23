## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::setting 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export setting
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration settings

namespace eval ::fx::validate::setting {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::setting::release  {p x} { return }
proc ::fx::validate::setting::validate {p x} {
    set cx [string tolower $x]
    if {$cx in [dict keys [Legal]]} { return $cx }
    fail $p SETTING "a configuration setting" $x
}

proc ::fx::validate::setting::default  {p} { return {} }
proc ::fx::validate::setting::complete {p} {
    complete-enum [dict keys [Legal]] 1 $x
}

# # ## ### ##### ######## ############# ######################

proc ::fx::validate::setting::Legal {} {
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

    # editable validateset db-name default
    return {
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
package provide fx::validate::setting 0
return
