# -*- tcl -*-
# # ## ### ##### ######## ############# #####################

## Bits and pieces of this should be moved to
## tcllib's term::ansi::ctrl::unix.
## These are in the ctrl child namespace.

# # ## ### ##### ######## ############# #####################

package require Tcl 8.5
package require fx::color
package require linenoise
package require try
package require fx::table
package require textutil::adjust

namespace eval ::fx {
    namespace export term
}
namespace eval ::fx::term {
    namespace export \
	ask/string ask/string* ask/yn ask/choose ask/menu \
	wrap
    namespace ensemble create

    namespace import ::fx::color
}

# # ## ### ##### ######## ############# #####################

proc ::fx::term::ask/string {query {default {}}} {
    try {
	set response [Interact {*}[Fit $query 10]]
    } on error {e o} {
	if {$e eq "aborted"} {
	    error Interrupted error SIGTERM
	}
	return {*}${o} $e
    }
    if {($response eq {}) && ($default ne {})} {
	set response $default
    }
    return $response
}

proc ::fx::term::ask/string/extended {query args} {
    # accept  -history, -hidden, -complete
    # plus    -default
    # but not -prompt

    # for history ... integrate history load/save from file here?
    # -history is then not boolean, but path to history file.

    set default {}
    set config {}
    foreach {o v} $args {
	switch -exact -- $o {
	    -history -
	    -hidden -
	    -complete {
		lappend config $o $v
	    }
	    -default {
		set default $v
	    }
	    default {
		return -code error "Bad option \"$o\", expected one of -history, -hidden, -prompt, or -default"
	    }
	}
    }
    try {
	set response [Interact {*}[Fit $query 10] {*}$config]
    } on error {e o} {
	if {$e eq "aborted"} {
	    error Interrupted error SIGTERM
	}
	return {*}${o} $e
    }
    if {($response eq {}) && ($default ne {})} {
	set response $default
    }
    return $response
}

proc ::fx::term::ask/string* {query} {
    try {
	set response [Interact {*}[Fit $query 10] -hidden 1]
    } on error {e o} {
	if {$e eq "aborted"} {
	    error Interrupted error SIGTERM
	}
	return {*}${o} $e
    }
    return $response
}

proc ::fx::term::ask/yn {query {default yes}} {
    append query [expr {$default
			? " \[[color green Y]n\]: "
			: " \[y[color green N]\]: "}]

    lassign [Fit $query 5] header prompt
    while {1} {
	try {
	    set response \
		[Interact $header $prompt \
		     -complete {::fx::term::Complete {yes no false true on off 0 1} 1}]
		     
	} on error {e o} {
	    if {$e eq "aborted"} {
		error Interrupted error SIGTERM
	    }
	    return {*}${o} $e
	}
	if {$response eq {}} { set response $default }
	if {[string is bool $response]} break
	puts stdout [wrap "You must choose \"yes\" or \"no\""]
    }

    return $response
}

proc ::fx::term::ask/choose {query choices {default {}}} {
    set hasdefault [expr {$default in $choices}]

    set lc [linsert [join $choices {, }] end-1 or]
    if {$hasdefault} {
	set lc [string map [list $default [color green $default]] $lc]
    }

    append query " ($lc): "

    lassign [Fit $query 5] header prompt

    while {1} {
	try {
	    set response \
		[Interact $header $prompt \
		     -complete [list ::fx::term::Complete $choices 0]]
	} on error {e o} {
	    if {$e eq "aborted"} {
		error Interrupted error SIGTERM
	    }
	    return {*}${o} $e
	}
	if {($response eq {}) && $hasdefault} {
	    set response $default
	}
	if {$response in $choices} break
	puts stdout [wrap "You must choose one of $lc"]
    }

    return $response
}

proc ::fx::term::ask/menu {header prompt choices {default {}}} {
    set hasdefault [expr {$default in $choices}]

    # Full list of choices is the choices themselves, plus the numeric
    # indices we can address them by. This is for the prompt
    # completion callback below.
    set fullchoices $choices

    set n 1
    table::do t {{} Choices} {
	foreach c $choices {
	    if {$default eq $c} {
		$t add ${n}. [color green $c]
	    } else {
		$t add ${n}. $c
	    }
	    lappend fullchoices $n
	    incr n
	}
    }
    $t plain
    $t noheader

    lassign [Fit $prompt 5] pheader prompt

    while {1} {
	if {$header ne {}} {puts stdout $header}
	$t show* {puts stdout}

	try {
	    set response \
		[Interact $pheader $prompt \
		     -complete [list ::fx::term::Complete $fullchoices 0]]
	} on error {e o} {
	    if {$e eq "aborted"} {
		error Interrupted error SIGTERM
	    }
	    return {*}${o} $e
	}
	if {($response eq {}) && $hasdefault} {
	    set response $default
	}

	if {$response in $choices} break

	if {[string is int $response]} {
	    # Inserting a dummy to handle indexing from 1...
	    set response [lindex [linsert $choices 0 {}] $response]
	    if {$response in $choices} break
	}

	puts stdout [wrap "You must choose one of the above"]
    }

    $t destroy
    return $response
}

proc ::fx::term::Complete {choices nocase buffer} {
    if {$buffer eq {}} {
	return $choices
    }

    if {$nocase} {
	set buffer [string tolower $buffer]
    }

    set candidates {}
    foreach c $choices {
	if {![string match ${buffer}* $c]} continue
	lappend candidates $c
    }
    return $candidates
}

proc ::fx::term::Interact {header prompt args} {
    if {$header ne {}} { puts $header }
    linenoise prompt {*}$args -prompt $prompt
}

proc ::fx::term::Fit {prompt space} {
    # Similar to fx::log::wrap, except wrapping is conditional
    # here, with a split following.
    global env
    if {[info exists env(FX_NO_WRAP)]} {
	return [list {} $prompt]
    }

    set w [expr {[linenoise columns] - $space }]
    # we leave space for some characters to be entered.

    if {[string length $prompt] < $w} {
	return [list {} $prompt]
    }

    set prompt [textutil::adjust::adjust $prompt -length $w -strictlength 1]

    set prompt [split $prompt \n]
    set header [join [lrange $prompt 0 end-1] \n]
    set prompt [lindex $prompt end]
    # alt code for the same.
    #set header [join [lreverse [lassign [lreverse [split $prompt \n]] prompt]] \n]
    append prompt { }

    list $header $prompt
}

proc ::fx::term::wrap {text {down 0}} {
    global env
    if {[info exists env(FX_NO_WRAP)]} {
        return $text
    }
    set c [expr {[linenoise columns]-$down}]
    return [textutil::adjust::adjust $text -length $c -strictlength 1]
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide fx::term 0
