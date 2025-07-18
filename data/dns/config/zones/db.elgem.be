$TTL    604800
@       IN      SOA     ns1.elgem.be. admin.elgem.be. (
                             2         ; Serial
                        604800         ; Refresh
                         86400         ; Retry
                       2419200         ; Expire
                        604800 )       ; Negative Cache TTL

; Nameservers
@       IN      NS      ns1.elgem.be.
@       IN      NS      ns2.elgem.be.

; Wildcard for all subdomains
elgem.be.    IN      A       192.168.1.196
*.elgem.be.    IN      A       192.168.1.196
