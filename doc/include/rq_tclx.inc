
[subsection Tclx]

The project uses the [package Tclx] package in its implementation.

[para] Out of the many possibilites for getting Tclx (OS vendor,
os-independent vendor, building from sources) use whatever you are
comfortable with.

[para] For myself, I am most comfortable with using
[uri http://www.activestate.com ActiveState's]
ActiveTcl distribution and TEApot.

[para] See the previous section ([sectref Tcl]) for disclosure and
information on how to get it.

[para] Assuming that ActiveTcl got installed running the command

[example {
    teacup install Tclx
}]

will install Tclx for your platform, if you have not done the more inclusive

[example {
    teacup update
}]

to get everything and the kitchensink.

[para] For those wishing to build and install Tclx on their own, the
relevant sources can be found at

[list_begin definitions]
[def Tclx] [uri http://sourceforge.net/projects/tclx]
[list_end]

together with the necessary instructions on how to build it.

[para] If there are problems with building, installing, or using Tclx
please file a bug against Tclx, or the vendor of your distribution,
and not [vset PROJECT].
