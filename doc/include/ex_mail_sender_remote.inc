
First we deal with the mail configuration. This is all about which
host to use for injecting mail into the network, on which port,
encrypted or not, the necessary credentials, etc.

[para] Here are the relevant commands:

[example {
    fx repository set /path/to/the/fossil/repository/file
    fx note config set host     your-mail-host
    fx note config set user     your-mail-username
    fx note config set password your-mail-password
    fx note config set sender   your-project-maintainer-email-address

    fx note config export /path/to/mail-config-backup
    fx repository reset
}]

[para] Some notes:

[list_begin itemized]
[comment ------------------------------------------------------------]
[item]	The example uses the [cmd {fx repository set|reset}] commands
	to avoid typing

[example {
    -R /path/to/the/fossil/repository/file
}]

in each configuration command of the example. This is just visual
clutter. In actual script it is recommended to use [option -R]
however, as this allows the parallel execution of the script for
different repositories. The set|reset commands involve global state,
the "default repository", which forces serialization to avoid the
script instances from intefering with each other.

[comment ------------------------------------------------------------]
[item] The attributes [term host], [term user], and [term password]
should be self-explanatory. They are the mail host to talk to, as
specified by your network administrator and/or ISP, and the
credentials it expects to allow access.

[para] There is a [term port] attribte as well, which needs to be set
if and only if a non-standard port is used for SMTP.

[para] Similarly the [term tls] attribute (a boolean) has to be set
only if the mail system requires a TLS/SSL-encrypted connection.

[comment ------------------------------------------------------------]
[item] The value of [term sender] should be some thought put
into.

This email address will appear as the 'From' header in all generated
mails. If a receiver of some notification has an issue they will
likely respond to this address.

Mail delivery errors, i.e. bounces will be sent to this address as
well.

Lastly, [vset PROJECT] will send the stacktraces of all internal
errors caught during operation there.

As such it is strongly recommended to make this a proper and valid
address, for the person or group which manages this setup.

[comment ------------------------------------------------------------]
[item] Note that the attribute [term location] is not configured.
As we are using a local clone of a remote project this information
can be and is infered from the remote url we cloned from.

[comment ------------------------------------------------------------]
[item] Of all the settings above the [term location] is the only one
which is a decidedly per-repository item.

For all other settings it makes sense to configure them at the global
level, to be shared across all managed repositories. Assuming that
there is more than one repository getting managed.

To do so is as simple as adding the option [option --global] to the
configuration commands, like

[example {
    fx note config set --global host your-mail-host
}]


[comment ------------------------------------------------------------]
[item] The last command in the example, the [cmd {note config export}]
is technically not required, as it [emph only] makes a backup of the
configuration in a text file.

[para] It is in the example due to my belief that having a backup,
always, is good policy, and to drive this belief.

[para] And together with the complementary [cmd {note config import}]
command this is also another way of copying a mail setup around and
applying it to multiple repositories.

[comment ------------------------------------------------------------]
[list_end]
