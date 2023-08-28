## Basic Linux cheat sheet

## install traceroute ##
sudo apt-get update && sudo apt-get install traceroute 

**add nginx**
sudo apt-get update & sudo apt-get install nginx

**tcp dump port 80 removing Azure info**
sudo tcpdump -i eth0 -nn -s0 -v port 80 and host not 168.63.129.16

**icmp specific hosts**
sudo tcpdump -nni eth0  icmp and host 10.1.2.4 and host 10.2.5.10

**Linux ping to include successful and failed pings**
ping 10.100.10.4 -O | while read pong; do echo "$(date): $pong"; done

**Linux ping display failed pings only**
ping 10.100.10.4 -O | while read pong; do echo "$(date): $pong"; done | grep answer

**Linux ping to include failed pings, write to file**
ping 10.100.10.4 -O | while read pong; do echo "$(date): $pong"; done > /tmp/TimeStamp-Ping.log

**Linux view previous file**
cat /tmp/TimeStamp-Ping.log

**Linux count lines in a log**
wc -l /tmp/TimeStamp-Ping.log
