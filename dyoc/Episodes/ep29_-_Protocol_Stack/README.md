# Design Your Own Computer
# Episode 29 : "Protocol Stack"
 
Welcome to "Design Your Own Computer".  In this episode we'll add a network
protocol stack.

## TCP/IP network protocol stack
We will be using the TCP/IP stack implementation from
[https://github.com/cc65/ip65](https://github.com/cc65/ip65).  The main
requirements of this protocol stack is to have defined three functions:
eth\_init, eth\_rx, and eth\_tx.  Fortunately, these functions are already
implemented in the previous episodes, so it is very simple to get the protocol
stack running.

## Sample application
I'm using the simple Date65 example application. After reset this application
first sends out a DHCP request to obtain an IP address from the local router.
Then it sends a DNS lookup for the address pool.ntp.org. Finally, it contacts
this server to obtain the current date and time, and then displays this on the
VGA output.
