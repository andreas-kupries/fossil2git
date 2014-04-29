
[subsection Tcllib]

[vset PROJECT]'s internals require the following 11 packages found in
Tcllib.

[list_begin enumerated]
[enum] [package clock::iso8601]
[enum] [package debug]
[enum] [package debug::caller]
[enum] [package interp]
[enum] [package lambda]
[enum] [package mime]
[enum] [package report]
[enum] [package smtp]
[enum] [package struct::matrix]
[enum] [package term::ansi::code::ctrl]
[enum] [package textutil::adjust]
[enum] [package try]
[list_end]

[para] Beyond that however the rest of Kettle will be fully
functional.

[para] Out of the many possibilities for getting Tcllib (OS vendor,
os-independent vendor, building from sources) use whatever you are
comfortable with.

[para] For myself, I am most comfortable with using
[uri http://www.activestate.com ActiveState's]
ActiveTcl distribution and TEApot.

[para] See the previous section ([sectref Tcl]) for disclosure and
information on how to get it.

[para] Assuming that ActiveTcl got installed running the commands

[example {
    teacup install clock::iso8601
    teacup install debug
    teacup install debug::caller
    teacup install interp
    teacup install lambda
    teacup install mime
    teacup install report
    teacup install smtp
    teacup install struct::matrix
    teacup install term::ansi::code::ctrl
    teacup install textutil::adjust
    teacup install try
}]

will install them for your platform, if you have not done the more
inclusive

[example {
    teacup update
}]

to get everything and the kitchensink.

[para] For those wishing to build and install Tcllib on their own, the
relevant sources can be found at

[list_begin definitions]
[def Tcllib] [uri http://sourceforge.net/projects/tcllib]
[list_end]

together with the necessary instructions on how to build it.

[para] If there are problems with building, installing, or using Tklib
and its packages please file a bug against Tklib, or the vendor of
your distribution, and not [vset PROJECT]
