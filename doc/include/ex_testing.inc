
While the setup is in principle done with the two previous sections I
believe that it is a not good idea to immediately jump to the
monitoring. Better test the setup first.

To start, a general test that the configured mail settings work:

[example {
    fx test mail-setup 'Andreas Kupries <andreask@activestate.com>'
}]

[para] The command in the example sends a fixed mail to the specified
destination address, using all the settings of section
[sectref {Sending Mail}].

[para] If that is ok, do


[example {
    fx note update-history
}]

This command explicitly updates the cached history of the ticket
fields mentioning for the dynamic routing (see last section).

[para] The initial run can take some time, depending on the size of
the pre-existing timeline, thus it feels nicer to me to do this
separately instead of as part of the next group of commands.

[example {
    fx test manifest-parse --all
    fx test mail-receivers --all
    fx test mail-for       --all
}]

[para] These commands go over all the changes i nthe repository and
checks that the system is able to parse their manifests, can generate
a list of destination mail addresses for them, and generate mail for
them.

[para] Any problems will be shown in the resulting table.

[para] This is less of a test of the repository and setup but more a
test that the system can deal with all the data found in the
repository. This is especially useful when operating on large
repositories, like Tcl, Tk, etc. as this is essentially a stress-test
of the tool internals, with a higher probability of testing even
things which are usually not found or simply rare (like, for example,
signed manifests, huge manifests, etc).
