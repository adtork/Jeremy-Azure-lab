## Basic Linux cheat sheet

**install traceroute**
<pre lang="...">
sudo apt-get update && sudo apt-get install traceroute 
</pre>

**add nginx**
<pre lang="...">
sudo apt-get update & sudo apt-get install nginx
</pre>

**tcp dump port 80 removing Azure info**
<pre lang="...">
sudo tcpdump -i eth0 -nn -s0 -v port 80 and host not 168.63.129.16
</pre>

**icmp specific hosts**
<pre lang="...">
sudo tcpdump -nni eth0  icmp and host 10.1.2.4 and host 10.2.5.10
</pre>

**Linux ping to include successful and failed pings**
<pre lang="...">
ping 10.100.10.4 -O | while read pong; do echo "$(date): $pong"; done
</pre>

**Linux ping display failed pings only**
<pre lang="...">
ping 10.100.10.4 -O | while read pong; do echo "$(date): $pong"; done | grep answer
</pre>

**Linux ping to include failed pings, write to file**
<pre lang="...">
ping 10.100.10.4 -O | while read pong; do echo "$(date): $pong"; done > /tmp/TimeStamp-Ping.log
</pre>

**Linux view previous file**
<pre lang="...">
cat /tmp/TimeStamp-Ping.log
</pre>

**Linux count lines in a log**
<pre lang="...">
wc -l /tmp/TimeStamp-Ping.log
</pre>
