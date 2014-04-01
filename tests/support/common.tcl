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
    # The test home directory is placed outside of the test tmp dir,
    # which is inside of the fossil checkout, and thus prevents use of
    # other fossil repositories.
    #set tmp [tmp]
    set tmp [fileutil::tempdir]

    set r [file join $tmp fxhome.[pid]]
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

proc the-ckout {} {
    return [thehome]/ckout
}

proc therepo {} {
    return [thehome]/source.fossil
}

proc in-ckout {script} {
    uplevel 1 [list indir [the-ckout] $script]
}

proc on-stage {script} {
    uplevel 1 [list indir [the-ckout] $script]
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
    # run fx command with arguments
    run-core [Where] {*}$args
}

proc run-core {args} {
    # args = command to run...
    variable verbose
    if {$verbose} { puts "[pwd] %% $args" }

    set out [file join [tmp] [pid].out]
    set err [file join [tmp] [pid].err]

    global env
    set here $env(HOME)
    try {
	file delete $out $err
	set env(HOME) [thehome]
	set env(FX_COLUMNS) -1
	set fail [catch {
	    exec > $out 2> $err {*}$args
	}]
    } finally {
	set   env(HOME) $here
	unset env(FX_COLUMNS)
    }

    Capture $out $err $fail
}

proc stage-open {} {
    file delete -force [thehome];# auto close if left open.
    file mkdir         [thehome]

    # Create standard fossil repository
    # And a standard checkout from that.
    # Implied: A standard global repository

    # NOTE: The use of run-core ensures that everything is done under
    # the fake home directory instead twiddling with the user
    # executing the testsuite.

    indir [thehome] {
	run-core fossil new source.fossil
	file mkdir ckout
	indir ckout {
	    run-core fossil open ../source.fossil
	}
    }
    return
}

proc stage-close {} {
    file delete -force [thehome]
    return
}

proc Where {} {
    # Note: Using the 'fx' app found in the test
    # installation.

    # TODO: Force the app to search its packages in the testinstall as
    # well. The kettle testutilities do that for the packages used
    # directly from the testfile. It does not the same for a child
    # process.

    # Hm. Maybe a tclsh child process with testutils loaded and then
    # using the fx package directly. I.e. an fx app customized for use
    # within the testsuite.

    set exe [auto_execok fx]

    #variable ::kt::localprefix
    #set exe $localprefix/bin/fx
    proc Where {} [list return $exe]
    return $exe
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
## Process the artifact example archive

proc stage-manifests {} {
    set id 2
    foreach f [lsort -dict [glob [tmp]/support/manifests/*]] {
	set archive [fileutil::cat -translation binary -encoding binary $f]

	# strip the header preventing interpretation of the example as
	# manifest or other special artifact within the fx repository.
	regexp "^(.*)ZA\n(.*)$" $archive -> header archive
	lassign	[split $header \n] _ etype ecomment
	set ecomment [string map {' ''} $ecomment]

	# save manifest into transient file and put into the repository.
	in-ckout {
	    fileutil::writeFile -translation binary -encoding binary [pid].ar $archive
	    run-core fossil test-content-put [pid].ar
	    file delete [pid].ar
	    if 1 {run-core fossil sqlite3 << [subst {
		INSERT INTO event VALUES (
		  '$etype',
		  julianday('now'),         -- mtime
		  $id,         -- objid
		  NULL,        -- tagid
		  NULL,        -- uid/user
		  NULL,        -- bgcolor
		  NULL,        -- euser
		  NULL,        -- user
		  '$ecomment', -- ecomment
		  NULL,        -- comment
		  NULL,        -- brief
		  julianday('now')         -- omtime
		);
	    }]}
	}
	incr id
    }
    # Regenerate the derived tables
    #run-core fossil rebuild
    return
}

proc the-manifests {} {
    return [split [string trim [fileutil::cat [tmp]/support/manifests-uuid.txt]] \n]
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
