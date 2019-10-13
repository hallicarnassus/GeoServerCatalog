#!/bin/bash
#script for ubuntu 18.04 (bionic)
#maintance by aji19kamaludin@gmail.com
#webuzo with opengeo by boundless

# phppgadmin
# http://ip/phppgadmin
# username : gisadmin
# password : gisadmin
# webuzo
# http://ip:2004
# username : admin
# password : admin

#varible
uname=admin
password='!Q@W#E$R'
email='admin@webgis.my.id'
domain='webgis.my.id'

#update system
export DEBIAN_FRONTEND=noninteractive
apt update && apt dist-upgrade -y

#set hostname
hostnamectl set-hostname webuzo-opengeo-$domain

#install docker
apt --no-act install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install docker-ce docker-ce-cli containerd.io -y

#build opengeo from docker
docker volume create gdp-geoserver_datadir
docker run --name "opengeo-gdp" -dit --restart unless-stopped -v gdp-geoserver_datadir:/var/lib/opengeo/geoserver -p 8080:8080 rikyperdana/ubuntu-opengeo
docker exec opengeo-gdp service postgresql start
docker exec opengeo-gdp service tomcat7 start

#make it automation in reboot : exit rc.local
printf '%s\n' '#!/bin/bash' 'exit 0' | sudo tee -a /etc/rc.local
cd /etc/systemd/system/
wget https://gist.githubusercontent.com/gisdeployid/6018e7c83f2d435544c0b14105e10c3a/raw/f7f0566dc2b81ced2dfcacf82357d1ed78e992f5/rc-local.service
systemctl enable rc-local
chmod +x /etc/rc.local
sed -i -e '$i \docker container start opengeo-gdp &\n' /etc/rc.local
sed -i -e '$i \docker exec opengeo-gdp service postgresql start &\n' /etc/rc.local
sed -i -e '$i \docker exec opengeo-gdp service tomcat7 start &\n' /etc/rc.local
sed -i -e '$i \docker container start portainer &\n' /etc/rc.local
sed -i -e '$i \systemctl start webuzo &\n' /etc/rc.local

#install portainer for console 
docker volume create portainer_data
docker run --name "portainer" -dit --restart unless-stopped -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer

#install webuzo and kill apache1, mysql is here
cd /tmp
wget -N http://files.webuzo.com/install.sh 
chmod 0755 install.sh 
./install.sh

#finishing install web based
curl -d "uname=$uname&email=$email&pass=$password&rpass=$password&domain=$domain&ns1=ns1.$domain&ns2=ns2.$domain&lic=&submit=Install+Webuzo" -X POST http://$(curl ifconfig.me):2004/install.php

kill -9 $(ps aux | grep apache | awk '{print $2}')

mv /usr/local/apps/apache/etc/httpd.conf /usr/local/apps/apache/etc/httpd.conf.bak

#install lamp
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E5267A6C
add-apt-repository "deb http://ppa.launchpad.net/ondrej/php/ubuntu $(lsb_release -cs) main "
apt-get update
apt install apache2 php7.3 php7.3-cli php7.3-common php7.3-curl php7.3-dev php7.3-gd php7.3-imap php7.3-intl php7.3-json php7.3-mbstring php7.3-mysql php7.3-pgsql php7.3-phpdbg php7.3-sqlite3 php7.3-sybase php7.3-xml php7.3-xmlrpc php7.3-xsl php7.3-zip libapache2-mod-php7.3 php7.3-fpm zip unzip -y
a2enmod rewrite userdir suexec ssl actions include cgi dav_fs dav auth_digest headers proxy_fcgi alias
echo "config" > /etc/apache2/conf-available/httpoxy.conf
sed -i -e '/config/c \<IfModule mod_headers.c> \nRequestHeader unset Proxy early\n </IfModule>' /etc/apache2/conf-available/httpoxy.conf
a2enconf httpoxy
sed -i '/DocumentRoot/c\DocumentRoot /home/'$uname'/public_html\n' /etc/apache2/sites-available/000-default.conf
sed -i -e '16i \<Directory /home/'$uname'/public_html> \nOptions Indexes FollowSymlinks MultiViews \nAllowOverride All \nRequire all granted\n </Directory>\n' /etc/apache2/sites-available/000-default.conf
sed -i -e '21i \<IfModule proxy_fcgi_module> \n<IfModule setenvif_module> \nSetEnvIfNoCase ^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1 \n</IfModule> \n<FilesMatch ".+\.ph(ar|p|tml)$"> \nSetHandler "proxy:unix:/run/php/php7.3-fpm.sock|fcgi://localhost" \n</FilesMatch> \n<FilesMatch ".+\.phps$"> \nRequire all denied \n</FilesMatch> \n<FilesMatch "^\.ph(ar|p|ps|tml)$"> \nRequire all denied \n</FilesMatch> \n</IfModule>' /etc/apache2/sites-available/000-default.conf
su -c "echo '<?php phpinfo(); ?>' > /home/$uname/public_html/index.php" $uname

#path php.ini from webuzo to /etc/php/7.3
sed -i '/user = www-data/c\user = '$uname /etc/php/7.3/fpm/pool.d/www.conf
sed -i '/group = www-data/c\group = '$uname /etc/php/7.3/fpm/pool.d/www.conf
sed -i '420i \php_admin_value[open_basedir] = /home/'$uname /etc/php/7.3/fpm/pool.d/www.conf
sed -i '420i \php_admin_value[disable_functions] = ' /etc/php/7.3/fpm/pool.d/www.conf

mv /usr/local/apps/php73/etc/php.ini /usr/local/apps/php73/etc/php.ini.back
ln -s /etc/php/7.3/fpm/php.ini /usr/local/apps/php73/etc/php.ini

systemctl restart apache2

#install postgresql, postgis, phppgadmin
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list
wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
apt update
apt install postgresql-11 postgresql-11-postgis-2.5  postgresql-11-postgis-scripts postgis postgresql-11-pgrouting zip unzip wget -y

su -c "psql -c 'CREATE EXTENSION adminpack;'" postgres
su -c "psql -c 'CREATE EXTENSION postgis;'" postgres
su -c "psql -c \"CREATE USER gisadmin SUPERUSER PASSWORD 'gisadmin';\"" postgres

sed -i "/\#listen/a listen_addresses='*'" /etc/postgresql/11/main/postgresql.conf
sed -i '$i \host all all 0.0.0.0/0 md5 \n' /etc/postgresql/11/main/pg_hba.conf
systemctl restart postgresql

cd /tmp;wget https://github.com/phppgadmin/phppgadmin/archive/REL_5-6-0.zip;
wget https://gist.githubusercontent.com/gisdeployid/c8f5b99d6b91ee3603b9552b8b105a4e/raw/33fec2c86be05cdf337a5c6e149d71f99fccf1a8/phppgadmin-config.inc.php;
unzip REL_5-6-0.zip -d /home/$uname
mv /home/$uname/phppgadmin-REL_5-6-0 /home/$uname/phppgadmin
cp /tmp/phppgadmin-config.inc.php /home/$uname/phppgadmin/conf/config.inc.php
echo "Alias /phppgadmin /home/$uname/phppgadmin" >> /etc/apache2/sites-enabled/000-default.conf
sed -i '$i <Directory /home/'$uname'/phppgadmin> \nOrder allow,deny \nAllow from all \nRequire all granted \n</Directory>\n' /etc/apache2/sites-enabled/000-default.conf

systemctl restart apache2

#ssh2 and ufw
sed -i "/\#Port/a Port=2202 \nProtocol 2" /etc/ssh/sshd_config
ufw enable
for port in 2202 2002 2003 2004 2005 21 22 25 53 80 143 443 465 993 3306 5432 8080 8000 8081
do
ufw allow $port
done

echo "Done" > /root/README.md
reboot