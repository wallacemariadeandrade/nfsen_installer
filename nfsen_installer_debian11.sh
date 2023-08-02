#!/bin/bash

# $1 = SERVER IP
# $2 = CONTACT EMAIL

SERVER_IP=""
CONTACT_EMAIL=""

################## VALIDACAO ######################

if [ "$SERVER_IP" = "" ]
 then
  echo "Abra o script e configure o IP do server!"
  exit 0
fi

if [ "$CONTACT_EMAIL" = "" ] 
 then
  echo "Abra o script e configure o email de contato!"
  exit 0
fi

#################### NFDUMP #######################

apt update -y && apt upgrade -y

mkdir ~/nfsen && cd ~/nfsen

apt install -y unzip make gcc flex rrdtool librrd-dev libpcap-dev php librrds-perl libsocket6-perl apache2 libapache2-mod-php libtool dh-autoreconf pkg-config libbz2-dev byacc doxygen graphviz librrdp-perl libmailtools-perl build-essential autoconf

git clone https://github.com/phaag/nfdump.git
git clone https://github.com/phaag/nfsen.git

a2enmod php7.4
sed -i "s/;date.timezone =/date.timezone=America\/Sao_Paulo /g" /etc/php/7.4/apache2/php.ini
sed -i 's/Alias \/icons\/ "\/usr\/share\/apache2\/icons\/"/#Alias \/icons\/ "\/usr\/share\/apache2\/icons\/"/g' /etc/apache2/mods-enabled/alias.conf

cd nfdump
./autogen.sh
./configure --enable-nsel --enable-nfprofile --enable-sflow --enable-readpcap --enable-nfpcapd --enable-nftrack

make && make install && ldconfig

yes | cpan App::cpanminus
cpanm Mail::Header
cpanm Mail::Internet

nfdump -V

###################### NFSEN #######################

cd /root/nfsen/nfsen/etc/
cp nfsen-dist.conf nfsen.conf

sed -i 's/$BASEDIR = "\/data\/nfsen"/$BASEDIR = "\/var\/nfsen"/g' nfsen.conf
sed -i 's/$WWWUSER  = "www"/$WWWUSER  = "www-data"/g' nfsen.conf 
sed -i 's/$WWWGROUP = "www"/$WWWGROUP = "www-data"/g' nfsen.conf

useradd -M -s /bin/false -G www-data netflow

mkdir – p /var/nfsen
cd ..

# 3 vezes para garantir
echo -ne '\n' | ./install.pl ./etc/nfsen.conf
echo -ne '\n' | ./install.pl ./etc/nfsen.conf
echo -ne '\n' | ./install.pl ./etc/nfsen.conf


##################### APACHE2 #######################

echo "
<VirtualHost *:80>
        # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        #ServerName www.example.com

        ServerName $SERVER_IP
        DirectoryIndex nfsen.php
        ServerAdmin $CONTACT_EMAIL
        DocumentRoot /var/www/nfsen

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with "a2disconf".
        #Include conf-available/serve-cgi-bin.conf
</VirtualHost>
" > /etc/apache2/sites-enabled/000-default.conf

/var/nfsen/bin/nfsen start
systemctl restart apache2

################### NFSEN SERVICE ####################

ln -s /var/nfsen/bin/nfsen /etc/init.d/nfsen
update-rc.d nfsen defaults 20
ln -s /var/www/nfsen/ /var/www/html/nfsen

echo "
[Unit]
Description=NfSen Service
After=network.target
[Service]
Type=forking
PIDFile=/var/nfsen/var/run/nfsend.pid
ExecStart=/var/nfsen/bin/nfsen start
ExecStop=/var/nfsen/bin/nfsen stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/nfsen.service

/etc/init.d/nfsen reconfig

systemctl enable nfsen
systemctl start nfsen
systemctl stop nfsen
systemctl stop nfsen
systemctl stop nfsen
systemctl start nfsen
systemctl start nfsen
systemctl start nfsen
systemctl status nfsen 

echo ""
echo "Nfsen instalado e pronto!"
echo "Para configurar os sources:"
echo " 1) nano /var/nfsen/etc/nfsen.conf"
echo " 2) Preencha a parte de sources conforme o modelo abaixo:
============================
%sources = (
    'RT_NE40_BGP'    => { 'port' => '9994', 'col' => '#26366a', 'type' => 'netflow', 'IP' => '172.20.1.2', 'optarg' => '-s -1000' },
);
============================

-s = amostragem de pacotes configurada no roteador

"
echo " 3) /etc/init.d/nfsen reconfig"
echo " 4) systemctl restart nfsen.service && systemctl status nfsen.service até aparecer o NFCAPD"