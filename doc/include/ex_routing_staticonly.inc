
Next after the low-level mail configuration we have to determine for
which events of the timeline we wish to get notifications, and where
to send them. This is called [term routing].

[para] For our example we go with the simplest possible setup and
declare that we are interested in all of them, and to send their
notifications to the same address. The command for that is

[example {
    fx note route add all the-destination-email-address
}]

Note that for clarity the option [option -R] was left out of the
command. Use either it or the "default repository", as shown in the
previous section.

[para] The [term all] argument is a catch-all term for all possible
events we might be interested in. Use the introspection command

[example {
    fx note route events
}]

to list the possible events we can use instead of [term all].

[para] The destination mail address can be anything, i.e. a single
person, a mail alias, a mailing list, etc. The latter would allow
people to subscribe to notifications from the repository without
having to deal directly with it.

[para] The above has handled the [term static] routing. Destinations
for notifications which are fixed for the repository and event.

[para] For ticket changes we normally can further configure the
[term dynamic] routing which enables the system to dynamically
generate mail for the people involved in a ticket in some way, be it
submitter, developer, commenter, etc.

However as a regular user we do not have access to the configuration
required for this, i.e. the areas [term users] and [term email].

So, in the situation of this example [term dynamic] routing is simply
not possible.

[para] After the routing has been set up it is recommended to make a
backup, using

[example {
    fx note route export /path/to/the/routes-backup
}]

Having a backup is always good idea, I believe. And together with the
complementary [cmd {note route import}] command this enables us to
apply the same routing setup to multiple repositories. Especially
important as we currently do not support global shared routing.
