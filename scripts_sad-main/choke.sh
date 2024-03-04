#!/bin/ash
set -ex
#Activar enrutado
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

#Limpiamos las reglas y contenedores
iptables -F
iptables -t nat -F
iptables -Z
iptables -t nat -Z

#POLITICAS POR DEFECTO
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

#4.permitir trafico loopbacck

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

#5. Permitir los pings
iptables -A INPUT -p icmp -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT

#6.Permitir consultas dns (A MI NOOO)
iptables -A OUTPUT -o eth0 -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -i eth0 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT


#8.Conectarme como cliente a servicios http/s para actualizar

iptables -A OUTPUT -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT


#10. Permitir conexiones ssh a mi servidor local

iptables -A INPUT -s 172.5.2.100 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -d 172.2.2.100 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT

#11. Permitir ping a la red interna
iptables -A FORWARD -i eth0 -o eth1 -p icmp -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -p icmp -j ACCEPT

#12. Permitir consultas DNS a la red interna
iptables -A FORWARD -i eth1 -o eth0 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -p udp --sport 53 -j ACCEPT

#14. Permitir todo el trafico TCP  saliente de la red interna hacia afuera
iptables -A FORWARD -i eth1 -o eth0 -p tcp -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -p tcp -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#SNAT (Source NAT) para salir al exterior
iptables -t nat -A POSTROUTING -o eth0 -s 172.5.0.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth0 -s 172.5.2.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth0 -s 172.5.1.0/24 -j MASQUERADE

#15.Conexion a servidor SSH de pc-lan-1
iptables -t nat -A PREROUTING -p tcp --dport 2022 -j DNAT --to 172.5.2.100:22
iptables -A FORWARD -i eth0 -d 172.5.2.100 -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -i eth1 -d 172.5.2.100 -p tcp --dport 22 -j ACCEPT

# Redirigimos el trafico al puerto 80
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to 172.5.1.2:80

#Permitimos trafico con el puerto 80 al servidor
iptables -A FORWARD -i eth0 -d 172.5.1.2 -p tcp --dport 80 -j ACCEPT
