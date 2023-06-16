# Linux Networking

Some concepts and commands when debugging network connections under Linux.
Note: All command outputs (IPs, MAC addresses, interface names) were changed,
so they are not the real values in my private network ;)

## Concepts

### How are packages routed in Linux?

- Packages are passed through _IP chains_.
- _IP chains_ are grouped together in `iptables`.
- Higher-level tools like the firewall `ufw` allow us to setup rules without
  having to interact with `iptables` directly.
- A lot of tools (like e.g. `docker`) insert their own rules directly into
  `iptables` and thus **bypass UFW**
  - If you start a container with a port binding to all IP addresses, you do not
    have to open the port in `ufw` because `docker` will insert a required rule
    in `iptables` directly.

### Forwarding in Linux

- If you want a server to function as a router between different networks, you
  need to set it up accordingly.
- This requires at least two steps:
  1. Set the value of `net/ipv4/ip_forward=1` in `/etc/ufw/sysctl.conf`.
  2. Add forward rules for your interfaces, examples are below.

Examples of forward rules

```bash
# Allow all traffic to pass from `eth3` to `eth4` (and reverse)
sudo ufw route allow in on eth3 out on eth4
sudo ufw route allow in on eth4 out on eth3

# Allow only traffic from `eth5` to `eth6` for TCP packets for a specific IP and port
sudo ufw route allow in on eth5 out on eth6 to 10.0.0.10 port 80 proto tcp
```

## Network assertions/tasks

Things to figure out when debugging a network setup.

### Am I connected to the internet?

Try pinging a public server that always answers, like the Cloudflare (`1.1.1.1`)
or Google (`8.8.8.8`) DNS servers.

```bash
ping 1.1.1.1
```

If everything is fine, you should see a response like this:

```
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=59 time=4.90 ms
64 bytes from 1.1.1.1: icmp_seq=2 ttl=59 time=4.70 ms
64 bytes from 1.1.1.1: icmp_seq=3 ttl=59 time=4.94 ms
```

Further notes:

- The ICMP protocol could be blocked selectively, so it is possible that you are
  connected to the internet via TCP/IP but you cannot send ICMP pings.

### Who else is on this network?

You can use `nmap` to scan for responding devices.

```bash
# Figure out which IP addresses you have yourself
hostname -I

# Response contains e.g. 192.168.0.31
sudo nmap -sP 192.168.0.0/24
```

A response might look like this:

```
Starting Nmap 7.80 ( https://nmap.org ) at 2022-10-20 08:31 CEST
Nmap scan report for fritz.box (192.168.0.1)
Host is up (0.0037s latency).
MAC Address: XX:XX:XX:XX:XX:XX (Unknown)
Nmap scan report for laptop.fritz.box (192.168.0.22)
Host is up (0.057s latency).
MAC Address: XX:XX:XX:XX:XX:XX (Unknown)
Nmap scan report for someones-iphone.fritz.box (192.168.0.23)
Host is up.
Nmap done: 256 IP addresses (3 hosts up) scanned in 2.07 seconds

```

Further notes:

- In some better-monitored networks (companies, hospitals etc.), a scan for all
  hosts might get you blocked automatically.

### Which network interfaces do I have?

You can list network interfaces with different commands depending on the OS.

```bash
# On newer Ubuntu systems
ip a

# On older Ubuntu systems
ifconfig
```

The output might look like this:

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: enp0f56s21: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq_codel state DOWN group default qlen 1000
    link/ether XX:XX:XX:XX:XX:XX brd ff:ff:ff:ff:ff:ff
3: wlp89s4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether XX:XX:XX:XX:XX:XX brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.22/24 brd 192.168.178.255 scope global dynamic noprefixroute wlp89s4
    ...
4: wireguard0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1400 qdisc noqueue state UNKNOWN group default qlen 1000
    link/none
    inet 10.0.0.1/16 scope global wireguard0
       valid_lft forever preferred_lft forever
5: wg_private: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1280 qdisc noqueue state UNKNOWN group default qlen 1000
    link/none
    inet 10.10.1.10/16 scope global wg_private
       valid_lft forever preferred_lft forever
6: br-fe9249sb9349: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:45:33:09:48:23 brd ff:ff:ff:ff:ff:ff
    inet 172.23.0.1/16 brd 172.23.255.255 scope global
       valid_lft forever preferred_lft forever
7: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:45:33:09:48:24 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
```

### How are packages routed on my machine?

You can list routing table entries but beware that some software redirects
packages without being reflected in the table.

```bash
ip route
```

The output might look like this:

```
default via 192.168.178.1 dev wlp58s0 proto dhcp metric 600
10.0.0.0/16 dev wireguard0 proto kernel scope link src 10.0.0.1
10.1.0.0/16 dev wireguard0 scope link
10.10.0.0/16 dev wg_private proto kernel scope link src 10.10.1.10
10.11.0.0/16 dev wg_private scope link
169.254.0.0/16 dev wlp89s4 scope link metric 1000
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
172.23.0.0/16 dev br-fe9249sb9349 proto kernel scope link src 172.23.0.1 linkdown
192.168.0.0/24 dev wlp89s4 proto kernel scope link src 192.168.0.22 metric 600
```

### Which processes are listening on which port?

```bash
sudo ss -tulpn | grep <port_number>

# Alternative tool
sudo netstat -tulpn | grep <port_number>
```

### Are packages arriving / leaving on a certain network interface?

You can use `tcpdump` on servers to capture packages according to certain
filters. On your local machine, the GUI-backed `wireshark` might be more
convenient.

```bash
# Listen for all traffic on interface `wireguard0`
sudo tcpdump -i wireguard0

# Listen for traffic on all interfaces from/to `10.10.1.2`
sudo tcpdump host 10.10.1.2

# There are a lot more filters for `tcpdump`, see e.g.
# https://docs.netgate.com/pfsense/en/latest/diagnostics/packetcapture/tcpdump.html
```

We can also save captured traffic and analyze it later in `wireshark` with a
GUI. The capturing can be done with `tshark` or `tcpdump`:

```bash
# Capture with tshark
sudo tshark -i eth1 -w my_capturing.pcap

# Capture with tcpdump
sudo tcpdump -i eth1 -w "capturing_$(date +%FT%T).pcap"
```

### Along which route am I connected to a server?

The tool `mtr` lists a chain of hop points to a server that we connect to. This
can be useful if we want to figure out via which gateway our traffic flows or
how much latency is lost where.

```bash
mtr www.google.de
```

Note that not every server along the way might answer.

### How do I connect to a remote server through an SSH tunnel?

```bash
ssh -L 127.0.0.1:8080:<server_ip_behind_remote>:80 remote_host
```

### How to forward a local port to another port on another server?

Let's imagine that you have a SSH tunnel open to a server with the IP
`10.10.1.2.` and this server in turn can reach a database at `big.db.com` on
port `8000`. You want to make this database service available on port `6002`
which your SSH tunnel is already bound to. You can do so with `socat`:

```bash
socat tcp-listen:6002,reuseaddr,fork tcp:big.db.com:8000
```

### How do I make a service in my network available to a server outside of my network?

This works via a reverse SSH tunnel. Let's imagine the following setup:

- In a company network, there is the server `connector` (`10.10.4.10`) which you
  have access to.
- In the same network, we have a database `db` (`10.10.5.10`) that can be
  accessed from `connector`. The database accepts connections on port `8000`.
- You have service running on the server `outsider` (`54.53.52.51`) which can be
  connected to over the public internet.

Let's open a reverse SSH tunnel from `connector` that makes the database on `db`
locally available on `outsider` on port `8200`:

```bash
# On `connector`
ssh -R 8200:10.10.5.10:8000 user@54.53.52.51
```

### How can I connect to a server via SSH through another server?

This works with so-called _jump-connections_ (agent-forwarding is required).
In the example above, we could use different keys/passwords for different hosts
on the way and as final target. We need all required keys only on our local
machine and not on any of the intermediate servers.

```bash
ssh -J user1@host1,user2@host2 targetuser@targethost
```

### How can I count incoming traffic?

A colleague taught me this trick to figure out if an active UDP filter stops
traffic. We will send zero data from a client to a server and count how much
data we receive. Active UDP filters will kill off the connection after a certain
amount of data transfered. This is a nifty issue e.g. for `wireguard`.

```bash
# Count incoming traffic

# Client
cat /dev/zero | nc -u 1.2.3.4 2000

# Server
sudo ufw allow 2000
nc -l -u 2000 | pv -b > /dev/null
```

### Observe bandwidth

```bash
sudo iftop -n
```

### How can I measure the bandwidth between two machines?

We can use `iperf3`.

```bash
# Measure bandwidth

# On server
sudo ufw allow 5201
iperf3 -s

# On client, -R optionally for reverse
iperf3 -c 5201
```

### How to use jumphost configurations?

Read on [here](https://ma.ttias.be/use-jumphost-ssh-client-configurations/)

### How can I ping a locally connected device via IPv6? (link-local)

To ping a locally connected device via IPv6, we need to specify the interface
used in addition to the address and use `ping6`. Below is an example using the
interface `enp0`

```bash
ping6 fe80::aabb:aabb:aabb%eth0
```

### How can I transfer files over IPv6?

One possibility is using `socat`, if nothing else is available. We need to
specify the device that we use.

```bash
# On the receiving side
socat -u TCP6-LISTEN:9191,reuseaddr OPEN:data.txt,creat

# On the sending side
socat -u FILE:data.txt TCP6:[fe80::aabb:aabb:aabb:aabb]:9191,so-bindtodevice=enp0
```

### How can I create a virtual network interface with a specific IPv6 and VLAN tag?

```bash
sudo ip link add link eth1 name eth1.5 type vlan id 5
sudo ip -6 addr add fd53:1111:222:3::4/64 dev eth1.5
sudo ip link set eth1 up
sudo ip link set eth1.5 up
```
