#!/bin/bash
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

#8.Conectarme como cliente a servicios http/s para actualizar
iptables -A OUTPUT -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#Permitir consultas DNS

iptables -A OUTPUT -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p udp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT



# Tráfico DMZ con el exterior para servicios expuestos en DMZ (80)
iptables -A FORWARD -d 172.5.1.2 -o enp0s8 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 172.5.1.2 -o enp0s3 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED -j ACCEPT 

# Trafico entre la red interna y el DMZ al servicio http.

iptables -A FORWARD -s 172.5.2.0/24 -d 172.5.1.2 -j LOG --log-level 6 --log-prefix andres


iptables -A FORWARD -s 172.5.2.0/24 -d 172.5.1.2  -o enp0s8 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

iptables -A FORWARD -s 172.5.1.2 -d 172.5.2.0/24 -o enp0s9 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED -j ACCEPT 




# Permitir actualizaciones de las máquinas de la DMZ (peticiones http y https)

  iptables -A FORWARD -i enp0s8 -s 172.5.1.0/24 -p tcp --dport 80 -m conntrack --ctstate  NEW,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -o enp0s8 -d 172.5.1.0/24 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A FORWARD -i enp0s8 -s 172.5.1.0/24 -p tcp --dport 443 -m conntrack --ctstate  NEW,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -o enp0s8 -d 172.5.1.0/24 -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permitir actualizaciones de las máquinas de la interna (peticiones http y https)

  iptables -A FORWARD -i enp0s9 -s 172.5.2.0/24 -p tcp --dport 80 -m conntrack --ctstate  NEW,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -o enp0s9 -d 172.5.2.0/24 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A FORWARD -i enp0s9 -s 172.5.2.0/24 -p tcp --dport 443 -m conntrack --ctstate  NEW,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -o enp0s9 -d 172.5.2.0/24 -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#FORWARDIND DE PETICIONES DNS DE LA DMZ
iptables -A FORWARD -i enp0s8 -s 172.5.1.0/24 -p udp --dport 53 -m conntrack --ctstate  NEW -j ACCEPT
iptables -A FORWARD -o enp0s8 -d 172.5.1.0/24 -p udp --sport 53 -m conntrack --ctstate  ESTABLISHED -j ACCEPT


#FORWARDIND DE PETICIONES DNS DE LA RED INTERNA
iptables -A FORWARD -i enp0s9 -s 172.5.2.0/24 -p udp --dport 53 -m conntrack --ctstate  NEW -j ACCEPT
iptables -A FORWARD -o enp0s9 -d 172.5.2.0/24 -p udp --sport 53 -m conntrack --ctstate  ESTABLISHED -j ACCEPT


#10. Permitir conexiones ssh a mi servidor local

iptables -A INPUT -s 172.5.2.100 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -d 172.5.2.100 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT


#11. Permitir ping a la red interna
iptables -A FORWARD -i enp0s3 -o enp0s9 -p icmp -j ACCEPT
iptables -A FORWARD -i enp0s9 -o enp0s3 -p icmp -j ACCEPT
iptables -A FORWARD -i enp0s8 -o enp0s9 -p icmp -j ACCEPT
iptables -A FORWARD -i enp0s9 -o enp0s8 -p icmp -j ACCEPT


#14. Permitir todo el trafico TCP  saliente de la red interna hacia afuera
iptables -A FORWARD -i enp0s9 -o enp0s3 -p tcp -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i enp0s3 -o enp0s9 -p tcp -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permitir todo el trafico TCP  saliente de la DMZ hacia afuera
iptables -A FORWARD -i enp0s8 -o enp0s3 -p tcp -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i enp0s3 -o enp0s8 -p tcp -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT


#15.Conexion a servidor SSH 
#iptables -t nat -A PREROUTING -p tcp --dport 2022 -j DNAT --to 172.2.1.2:22
iptables -A FORWARD -i enp0s9 -d 172.5.1.2 -s 172.5.2.100 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i enp0s8 -d 172.5.2.100 -s 172.5.1.2 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT


#Redirigir conexiones ssh de red interna exterior a la DMZ

iptables -A FORWARD -i enp0s9 -d 172.5.0.2 -s 172.5.2.100 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i enp0s3 -d 172.5.2.100 -s 172.5.0.2 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT

# Tráfico DMZ desde el exterior para servicios expuestos en DMZ (80)
iptables -A FORWARD -d 172.5.1.2 -o enp0s3 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 172.5.1.2 -o enp0s8 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED -j ACCEPT 

