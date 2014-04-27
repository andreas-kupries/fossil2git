## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::manifest 0
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
package require clock::iso8601
package require fx::color

debug level  fx/manifest
debug prefix fx/manifest {}

# # ## ### ##### ######## ############# ######################

namespace eval ::fx {
    namespace export manifest
    namespace ensemble create
}
namespace eval ::fx::manifest {
    namespace export parse
    namespace ensemble create

    namespace import ::fx::color
}

# # ## ### ##### ######## ############# ######################

proc ::fx::manifest::parse {manifest args} {
    debug.fx/manifest {parse [string length $manifest]}
    # Manifest array/dictionary collecting all important pieces.

    # Initalize with general data coming from outside the manifest itself.
    # self -> uuid of the manifest artifact.
    array set m $args

    # Map from cards to dictionary elements, and manifest types.
    ##                             Type
    # A     name,target,attachment,operation             attachment
    # B n/a                        checkin
    # C     comment
    # D     when
    # E     when-event,eventid
    # F n/a                        checkin
    # J     field - sub dictionary
    # K     ticket                 ticket
    # L     title                  wiki
    # M n/a
    # N     mimetype
    # P n/a
    # Q n/a                        checkin
    # R n/a                        checkin
    # T n/a [+*_]tag uuid ?value?         - event|control
    # U     user
    # W     text
    # Z n/a

    if {[string match {-----BEGIN PGP SIGNED MESSAGE-----*} $manifest]} {
	# Remove the leading lines of the signer's envelope until we
	# have the beginning of the manifest.
	debug.fx/manifest {[color note "trim envelope"]}
	set  pos [string first \n\n $manifest]
	incr pos 2
	set manifest [string range $manifest $pos end]
	debug.fx/manifest {left [string length $manifest]}
    }

    while {[regexp "^(\[ABCDEFJKLMNPQRTUWZ\])(\[^\n\]*)\n(.*)$" $manifest -> code data manifest]} {
	debug.fx/manifest {[color note "card $code"] ($data) left [string length $manifest]}

	# NOTE: We assume that arguments in data are separated by
	# spaces, without containing spaces of their own.  Values
	# which could contain spaces are armored.  Note, we have a
	# leading space in the data, thus will also have a leading
	# empty element in the resulting list. Instead of chopping
	# from the front, and shifting down (bad for large data) we
	# simply take this into account in our indexing.

	# With this in mind, we can and do use [split] to separate the
	# arguments, instead of [regexp]. Not just simpler, but also
	# much faster, especially on large data. For example: The
	# "icomment" J card in artifact
	#     3f6737f10b365a9248004c4d04cff88538ad85a5
	# of the Tcl repository. An icomment of over 475KB, an
	# embedded strace log. A [split] handles this in
	# sub-seconds. With [regexp] you will wait minutes!.

	switch -exact -- $code {
	    A {
		# Assume that arguments do not contain spaces.
		set data [split $data]

		if {[llength $data] == 4} {
		    debug.fx/manifest {-- attachment add}
		    # Attachment added - Target = uuid of { event, ticket }, or wiki page name
		    lassign $data _ m(attachment,path) m(target) m(attachment,uuid)
		    set m(type) attachment
		    set m(attachment,op) added
		    continue
		}
		if {[llength $data] == 3} {
		    debug.fx/manifest {-- attachment remove}
		    # Attachment removed - Target = uuid of { event, ticket }, or wiki page name
		    lassign $data _ m(attachment,path) m(target)
		    set m(type) attachment
		    set m(attachment,op) removed
		    continue
		}
		debug.fx/manifest {-- [color error "bad syntax"]}
		# error - bad syntax - ignored
	    }
	    B -
	    F -
	    Q -
	    R {
		debug.fx/manifest {-- =checkin}
		set m(type) checkin
	    }
	    C {
		debug.fx/manifest {-- comment}
		set m(comment) [Dearmor [string trim $data]]
	    }
	    D {
		debug.fx/manifest {-- when}
		set m(when) [string trim $data]
		set m(epoch) [Epoch $m(when)]
	    }
	    E {
		set data [split $data { }]
		if {[llength $data] == 3} {
		    debug.fx/manifest {-- when/event}
		    lassign $data _ m(when-event) m(eventid)
		    set m(epoch-event) [Epoch $m(when-event)]
		    set m(type) event
		    continue
		}
		debug.fx/manifest {-- [color error "bad syntax"]}
		# error - bad syntax - ignored
	    }
	    J {
		set data [split $data { }]
		if {[llength $data] == 3} {
		    lassign $data _ fname value
		    debug.fx/manifest {-- field = $fname (#[string length $value])}
		    dict set m(field) $fname [Dearmor $value]
		    continue
		}
		debug.fx/manifest {-- [color error "bad syntax"]}
		# error - bad syntax - ignored
	    }
	    K {
		set m(ticket) [string trim $data]
		set m(type) ticket
		debug.fx/manifest {-- =ticket ==> $m(ticket)}

		# NOTE: We do not have to retrieve the current ticket
		# state here. While we are interested in that, it is
		# actually only a partial interest, i.e. for the
		# fields inspected later to dynamically derive mail
		# destinations. That is something we can (and do)
		# handle outside (see fx::seen, => ticket timeseries
		# cache).
	    }
	    L {
		set m(title) [string trim $data]
		set m(type) wiki
		debug.fx/manifest {-- =wiki ==> $m(title)}
	    }
	    M {
		debug.fx/manifest {-- =cluster}
		set m(type) cluster
	    }
	    N {
		debug.fx/manifest {-- mimetype}
		set m(mimetype) [string trim $data]
	    }
	    P {
		debug.fx/manifest {-- parent}
	    }
	    T {
		set data [split $data { }]
		if {[llength $data] == 4} {
		    debug.fx/manifest {-- tag =}
		    lassign $data _ tagname taguuid tagvalue
		    dict set m(tags) $tagname [list $taguuid = [Dearmor $tagvalue]]
		    continue
		}
		if {[llength $data] == 3} {
		    debug.fx/manifest {-- tag !}
		    lassign $data _ tagname taguuid
		    dict set m(tags) $tagname [list $taguuid !]
		    continue
		}
		debug.fx/manifest {-- [color error "bad syntax"]}
		# error - bad syntax - ignored
	    }
	    U {
		debug.fx/manifest {-- user}
		set m(user) [string trim $data]
	    }
	    W {
		set data [string trim $data]
		# data = number of characters to take
		# we take one more, which is the closing \n, and chop
		# it off in the saved form.

		set text [string range $manifest 0 $data]
		incr data
		debug.fx/manifest {-- taken $data}

		set manifest [string range $manifest $data end]
		set m(text)  [string range $text 0 end-1]

		debug.fx/manifest {left [string length $manifest]}
	    }
	    Z {
		debug.fx/manifest {-- manifest checksum}
		break
		# prevent data from after the checksum to upset the parser.
		# like the trailing part of a signer's envelope.
	    }
	}
    }

    #parray m
    #puts --------------------------------

    if {![info exists m(type)]} {
	debug.fx/manifest {default type: control}
	set m(type) control
    }

    return [array get m]
}

# # ## ### ##### ######## ############# ######################
## Supporting code.

namespace eval ::fx::manifest {
    variable map [list \\s { } \\n \n \\t \t \\r \r]
}

proc ::fx::manifest::Dearmor {s} {
    variable map
    debug.fx/manifest {dearmor [string length $s]}
    # Should introduce K here
    return [string map $map $s]
}

proc ::fx::manifest::Epoch {when} {
    # Strip the subsecond part from the fossil time-stamp, ...
    regsub {\.\d+$} $when {} iso
    # ... then parse the now-regular ISO time into a proper epoch.
    return [clock::iso8601::parse_time $iso -gmt 1]
}

# # ## ### ##### ######## ############# ######################
## Manifest documentation. Cards, meaning and type of manifest.

# Ticket
# | Wiki
# | | Checkin
# | | | Control
# | | | | Cluster
# | | | | | Attachment (to ticket, wiki, or event)
# | | | | | | Event
# | | | | | | |
# T W C G - A E
#           *     A	uuid of attached file
#     *           B	uuid of baseline manifest (checkin is delta manifest)
#     *     * *   C	comment/description (of checkin or attachment)
# * * * *   * *   D	timestamp of change/manifest
#             *   E	event timestamp + uuid
#     *           F	file in checkin
# *               J	ticket field change
# *               K	uuid of ticket the change is for
#   *             L	wiki page title
#         *       M	uuid of artifact in the cluster
#   * *     * *   N	mimetype (of comment (C), wiki page (W))
#   * *       *   P	uuid of parent/prior checkin/page/event
#     *           Q	uuid of cherry picked parent checkin
#     *           R	repository checksum
#     * *     *   T	tag
# * * * *   * *   U	responsible user (name)
#   *         *   W	wiki page text, event text
# * * * * * * *   Z	manifest checksum
# K L ^   M A E		Primary identifying card.
#     BFQR

# Control artifacts, special (T)ags:
# 	user    -> U override
# 	comment -> C overrride
# 	date    -> D override

# Default N is text/x-fossil	Wiki page, Event description
# Default N is text/plain		Attachment

# Identifications

# A - *	Manifest is attachment
# E - *	Manifest is event
# B - 	Manifest is checkin
# F - 	Manifest is checkin
# J - 	Manifest is ticket change
# K - *	Manifest is ticket change
# L - *	Manifest is wiki page
# M - *	Manifest is cluster
# Q - 	Manifest is checkin
# R -  	Manifest is checkin

# When no other type claims the manifest:
# 	Manifest is control 

# # ## ### ##### ######## ############# ######################
package provide fx::manifest 0
return
