## (c) 2014 Andreas Kupries
# # ## ### ##### ######## ############# #####################

package require fileutil
package require try
package require sqlite3  ; # Test db access.

# # ## ### ##### ######## ############# #####################
## Configuration.

# # ## ### ##### ######## ############# #####################

proc NOTE {args} {
    #puts "@=NOTE: $args"
    return
}

proc TODO {args} {
    #puts "@=TODO: $args"
    return
}

# # ## ### ##### ######## ############# #####################
## Values derived from configuration

# # ## ### ##### ######## ############# #####################
##

proc tmp {} { tcltest::configure -tmpdir }

proc example {x} {
    return [file join [tmp] data apps $x]
}

proc result {x {suffix {}}} {
    set path [file join [tmp] data results$suffix ${x}.txt]
    if {![file exists $path]} { return {} }
    string trim [fileutil::cat $path]
}

proc map {x args} {
    string map $args $x
}

proc thehome {} {
    set r [file join [tmp] thehome]
    proc thehome {} [list return $r]
    return $r
}

proc indir {dir script} {
    set here [pwd]
    try {
	cd $dir
	uplevel 1 $script
    } finally {
	# Move kept files, if any, out of the temp directory to the
	# persistent place.
	foreach f [glob -nocomplain kept.*] {
	    file rename -force $f $here
	}
	cd $here
    }
}

proc withenv {script args} {
    global env
    set saved [array get env]
    try {
	array set env $args
	uplevel 1 $script
    } finally {
	array unset env *
	array set env $saved
    }
}

proc touch {path} {
    file mkdir [thehome]
    set path [thehome]/$path
    file mkdir [file dirname $path]
    fileutil::touch $path
    return $path
}

proc touchdir {path} {
    set path [thehome]/$path
    file mkdir $path
    return $path
}

proc debug   {} { variable verbose 1 }
proc nodebug {} { variable verbose 0 }

proc keep   {} { variable keep 1 }
proc nokeep {} { variable keep 0 }

proc run {args} {
    variable verbose
    if {$verbose} { puts "%% s $args" }

    set out [file join [tmp] [pid].out]
    set err [file join [tmp] [pid].err]

    global env
    set here $env(HOME)
    try {
	file delete $out $err
	set env(HOME) [thehome]
	set fail [catch {
	    exec > $out 2> $err [Where] {*}$args
	}]
    } finally {
	set env(HOME) $here
    }

    Capture $out $err $fail
}

proc stage-open {} {
    file delete -force [thehome];# auto close if left open.
    file mkdir         [thehome]
    # TODO: Create standard fossil repository
    # TODO: And a standard checkout from that.
    # Implied: Standard global repository
    return
}

proc stage-close {} {
    file delete -force [thehome]
    return
}

proc Where {} {
    # TODO: Get them from the test installation.
    set r [auto_execok fx]
    proc Where {} [list return $r]
    return $r
}

proc Capture {out err fail} {
    global status stdout stderr all verbose keep

    set status $fail
    set stdout [string trim [fileutil::cat $out]]
    set stderr [string trim [fileutil::cat $err]]
    set all [list $status $stdout $stderr]

    if {$keep} {
	file rename -force $out kept.out
	file rename -force $err kept.err
    } else {
	file delete $out $err
    }

    if {$verbose} {
	puts status||$status|
	puts stdout||$stdout|
	puts stderr||$stderr|
    }

    if {$fail || ($stderr ne {})} {
	if {$stderr ne {}} {
	    set msg $stderr
	} elseif {$stdout ne {}} {
	    set msg $stdout
	} else {
	    set msg {}
	}
	return -code error -errorcode FAIL $msg
    }

    return $stdout
}

# # ## ### ##### ######## ############# #####################

# Ok if the pattern is NOT matched.
proc antiglob {pattern string} {
    expr {![string match $pattern $string]}
}
tcltest::customMatch anti-glob antiglob

# # ## ### ##### ######## ############# #####################

nodebug
nokeep

# # ## ### ##### ######## ############# #####################
## Standard constraints.

# # ## ### ##### ######## ############# #####################
return
