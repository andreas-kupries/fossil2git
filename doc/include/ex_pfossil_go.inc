[include ex_peer_go.inc]

[para] A few things to remember however:

[list_begin enumerated]
[enum] cron is notoriously fiddly with regard to the environment
       variables provided to the jobs. Make sure that:

[enum] Your [var PATH] provides access to [syscmd fossil].

[enum] That a proper [var USER] variable is set for fossil to
       pick up. Or that it is specified in the peer url(s).

[list_end]
