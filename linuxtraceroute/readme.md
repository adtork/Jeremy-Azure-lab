sudo apt-get update && sudo apt-get install traceroute 


##add nginx
sudo apt-get update & sudo apt-get install nginx

# port 80 
sudo tcpdump -i eth0 -nn -s0 -v port 80 and host not 168.63.129.16

# icmp
sudo tcpdump -nni eth0  icmp and host 10.1.2.4 and host 10.2.5.10
