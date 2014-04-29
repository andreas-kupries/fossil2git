
[subsection TclOO]

The framework uses the [package TclOO] package in its implementation.
This package requires Tcl 8.5 or higher.

[para] In Tcl 8.6 the package is part of the core itself, without
requiring a separate installation.

[para] For Tcl 8.5 it has to be installed separately.

[para] Out of the many possibilites for getting TclOO (OS vendor,
os-independent vendor, building from sources) use whatever you are
comfortable with.

[para] For myself, I am most comfortable with using
[uri http://www.activestate.com ActiveState's]
ActiveTcl distribution and TEApot.

[para] See the previous section ([sectref Tcl]) for disclosure and
information on how to get it.

[para] Assuming that ActiveTcl got installed running the command

[example {
    teacup install TclOO
}]

will install the package for your platform, if you have not done the
more inclusive

[example {
    teacup update
}]

to get everything and the kitchensink.

[para] For those wishing to build and install TclOO on their own, the
relevant sources can be found at [uri http://core.tcl.tk/tcloo]
together with the necessary instructions on how to build it.

[para] If there are problems with building, installing, or using TclOO
and its packages please file a bug against TclOO, or the vendor of
your distribution, and not [package [vset PROJECT]].
