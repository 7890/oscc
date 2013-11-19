oscc - OSC Console
==================

oscc is a Java program that allows to "play around" with OSC (UDP).
It can be useful to manually interact with another OSC program. 
Using mappings and JavaScript methods, oscc supports to quickly 
develop and test inter-process communication models, OSC APIs 
and prototypes. oscc should be run only in trustful private subnets, 
since it can be configured to run native commands.

![oscc screenshot linux](screenshots/oscc_linux.png?raw=true)

![oscc screenshot osx](screenshots/oscc_osx.png?raw=true)

![oscc_screenshot windows](screenshots/oscc_windows.png?raw=true)

```
#using release package
tar xfvz oscc_lin32_latest.tgz
cd oscc_lin32_*
./oscc
```

```
OSCC help

Command line params:

   ./oscc help
   ./oscc <my port>
   ./oscc <my port> <remote host> <remote port>
   ./oscc <my port> <remote host> <remote port> <font name> <font size>
   ./oscc 10001
   ./oscc 10001 10.10.10.22 1234
   ./oscc 10001 10.10.10.22 1234 "Bitstream Vera Sans Mono" 14

    Note: a remote client will see source port=10001 (my port) in messages sent by me.

Built-in commands without arguments:

   clear    cl:   clear console
   disable  di:   do not process incoming OSC messages
   enable   en:   process incoming OSC messages
   log      lo:   start logging to file
   nolog    nl:   stop logging to file
   reload   rl:   reload actions configuration file
   reloadjs rj:   reload JavaScript file
   info     in:   show info on status (enabled/disabled etc.)
   about    ab:   additional info
   quit      q:   quit
   help      h:   this help text

How to set size of console font:

   fontsize:<size>
   fontsize:20

How to send an OSC message:

   <pattern>(;<typetag>;<param 1>(;<param n>))
   /hi/there
   /hi/with/params;sif;this is a string;1234;88.99
   OSC message must start with '/'

How to run native (platform-specific) commands

   local:<your command>
   local:oscsend localhost 10001 /test/from/ext/proc i 1
   Output of command to stdout/stderr will NOT be visible in oscc

How to trig actions on messages matching XYZ

See comments in file data/oscc_actions.csv on how to hook up actions 
to incoming OSC messages. With actions, you can run native commands on 
your platform or trigger JavaScript functions.

How to evaluate JavaScript from the console:

   js:<your JavaScript>
   js:a=42;println(a);
   js:my_loaded_function(99);

How to send OSC message from JavaScript:

   oscc.send('10.10.10.20',1234,'/hi/from/js;sif;a string;1;2.3');

How to print to console from JavaScript:

   oscc.p('hello from javascript');

How to run native command from JavaScript:

   oscc.runCmd('echo 1 > /tmp/00001.tmp')

JavaScript is loaded from file data/oscc_scripts.js
JavaScript must comply to ECMA (without object 'window' etc.) 

How to use oscc for setting/getting status information:

Basically the JavaScript context can be used for that. But you can also 
store OSC messages directly. An OSC message with it's pattern and arguments 
is a good container to store small, structured information like status.
External processes can store and retrieve OSC messages in oscc.

   //set/my/struct/as/osc/msg;sif;a string;1;2.3
   //get/my/struct/as/osc/msg

How to use oscc as a relay from the command line:

Temporary external processes can relay messages via oscc.
If the target will reply to sender, oscc will recieve it.

   //send/<pattern> si<more> <host> <port> <payload1> <payload2>..
   oscsend //send/my/pattern sis "10.10.10.20" 1234 "my payload"

How to setup a poller from JavaScript:

Only one poller can be used at the moment.

   setPoller(host,port,osccommand,interval)
   setPoller('localhost',7777,'/hello;s;there',500)

Stop/remove the poller:

   destroyPoller()

Console log prefixes:

   INF: info
   LDA: (re)load actions file
   LDJ: (re)load JavaScript file
   ADJ: add JavaScript action
   ADS: add shell / native action
   CNF: configuration setting enable/disable
   SND: send OSC message
   RCV: receive OSC message
   JSE: evaluate JavaScript
   JSR: return from JavaScript evaluation
   JSP: print to console from JavaScript
   ADM: add message to store (//set)
   GTM: get message from store (//get)
   CMD: native command
   ERR: error

```

```
#data/oscc_actions.csv:

#configuration file for OSC_CONSOLE
#entries share the following syntax:
#pattern;action;passparams

#hash and semicolon are comment characters

#action will be called with 
#/bin/sh (unix compat.) or cmd.exe (windows)

#params:
#select which params to pass to action with bitmask
#00 or empty: no params are passed
#first bit: oscpattern and ip address and port of sender
#second bit: available osc arguments
#10: oscpattern, from-ip, from-port (i.e. /bus1/test1 /10.10.10.38 1234)
#01: all arguments (i.e. 42 "hello world" 14.3)
#11: everything in the order 
#/my/oscpattern, from-ip, from-port, arg1, arg2, ...

#if action is a script, it must have executable flag set
#chmod 775 /tmp/my.sh
#scrtpt uri should be fully qualified starting with /..
#or c:\ respectively

;/bus1/test1;/tmp/my.sh;01
;/bus1/test2;/tmp/my.sh;10

#regular expression support to match osc pattern:
#  *: match anything
#  +: match anything up to next /
#  ?: match any single char
#  #: match any sequence of digits
#  examples: 
#  /hell* would match /hello, /helloworld,
#  /hello/world/xyz etc.
#  /hell+ would match /hello, /helluva, etc.
#  /a/+ would match /a/b, /a/xyz etc.
#  /a/+/c would match /a/b/c, /a/xyz/c, etc.
#  /a/*/c would match /a/b/c, /a/x/y/z/c etc.
#  /#/+/? would match /123/anything/a, /1/a/b etc.

;/a+/b+;/tmp/my.sh;11
;/#/?/+/*;/tmp/my.sh;11
;/start/prog;notepad.exe;01
;/hello/mac;open /Applications/TextEdit.app;00
;/gugus;oscsend localhost 10001 /foo i 42;00

;/ping;/tmp/non-existing.sh;11
/ping;send_pong_to();10

#...
```

```
#oscc_scripts.js:

#...

/*wrappers for calls to exposed functions from oscc*/
/*send osc message. message syntax like in OSC_CONSOLE*/
function send(host,port,message)
{
        oscc.send(host,port,message);
}

#...

function send_pong_to(pattern,host,port)
{
        send(host,port,'/pong');
}

#...

```
