#!/bin/bash

# ps_bootstrap.sh
# by martinm@rsysadmin.com
#
# Please, see the README.md for a full description.
#

# PrestaShop version to install
ps_version=1.7.4.2

# PHP version to install
# This blog offers a good overview on version compatibility:
# -> https://www.prestasoo.com/blog/prestashop-php-version
# This link offers a good guidance on how to install PHP:
# -> https://www.techsupportpk.com/2019/12/how-to-install-php-71-72-73-74-on-ubuntu-16-17-18-19.html
ps_php_version=7.4

# DB info
#
# Define values for your real DB (the one you will import once Prestashop is installed)
ps_real_db=[PROD_DB]
ps_real_db_user=[PROD_DB_USR]
ps_real_db_pass=[PROD_DB_PASSWD].
ps_real_db_prefix=[PROD_DB_PREFIX]                      # default is usually "ps_"
ps_real_db_sql_dump_file=[PROD_DB_SQL_DUMP_FILE]        # e.g.: myDB_dump.sql 

# You don't need to modify these if you don't want to.
# We'll use this DB to get Prestashop installed. 
# It can be dropped later on after importing $ps_real_db
ps_decoy_db=prestashop
ps_decoy_db_user=prestauser
ps_decoy_db_pass="Passw0rd1"

# Target directory; e.g.: mydomain.tld
# This is used to generate the SSL certs later on
ps_domain=$1
if [ -z $ps_domain ]
then
    echo "Usage: $(basename $0) <domain-name.tld>"
    echo " e.g.: $(basename $0) mydomain.tld"
    exit 1
fi

# SSL certificate data - adjust as needed
ssl_country=XX                      # e.g.: CH
ssl_state=[STATE]                   # e.g.: Zurich
ssl_location=[LOCATION]             # e.g.: Zurich
ssl_org="[MY_ORGANIZATION]"         # e.g.: Umbrella Corp.
ssl_ou="[MY_OU]"                    # e.g.: Project Alice
ssl_cn=$ps_domain

# Set your closest APT mirror (default: us, set to your country)
ps_apt_mirror=ch

# Set your time-zone
# ->  https://www.php.net/manual/en/timezones.php for valid values
ps_timezone="Europe/Zurich"        


# ----------------------------------------------------------------------------
# ----------- YOU SHOULD NOT NEED TO EDIT BELOW THIS LINE --------------------
# ----------------------------------------------------------------------------
ps_url="https://github.com/PrestaShop/PrestaShop/releases/download/${ps_version}/prestashop_${ps_version}.zip"
ps_dir=/var/www/html
ps_vhost_config=/etc/apache2/sites-available/$ps_domain.conf

# main()
echo "========= Update apt sources: US->CH ========"
sed -i "s/us./${ps_apt_mirror}./g" /etc/apt/sources.list

echo "========= Update apt cache ============"
sudo apt-get update

echo "========= Add APT repo for PHP ============"
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

echo "=========  Installing Apache 2 and PHP ${ps_php_version} ========= "
sudo apt-get install apache2 php${ps_php_version} \
        libapache2-mod-php${ps_php_version} \
        php${ps_php_version}-gd \
        php${ps_php_version}-mbstring \
        php${ps_php_version}-mysql \
        php${ps_php_version}-curl \
        php${ps_php_version}-intl \
        php${ps_php_version}-zip \
        php-xml \
        php-cli \
        unzip -y

echo "=========  Set PHP default version to ${ps_php_version} ========="
sudo update-alternatives --set php /usr/bin/php${ps_php_version}

php_config_output=$(php -i | grep -i cli/php.ini)
php_ini_path=$(echo "$php_config_output" | awk -F\> '{ print $2 }')

echo "=========  Update PHP options ========= "
echo "-- set file_uploads = On "
sed -i 's/^file_uploads =.*/file_uploads = On/g' $php_ini_path

echo "-- set allow_url_fopen = On"
sed -i 's/^allow_url_fopen =.*/allow_url_fopen = On/g' $php_ini_path

echo "-- set short_open_tag = On"
sed -i 's/^short_open_tag =.*/short_open_tag = On/g' $php_ini_path

echo "-- set memory_limit = 256M"
sed -i 's/^memory_limit =.*/memory_limit = 256M/g' $php_ini_path

echo "-- set cgi.fix_pathinfo = 0"
sed -i 's/^cgi.fix_pathinfo =.*/cgi.fix_pathinfo = 0/g' $php_ini_path

echo "-- set upload_max_filesize = 100M"
sed -i 's/^upload_max_filesize =.*/upload_max_filesize = 100M/g' $php_ini_path

echo "-- set max_execution_time = 360"
sed -i 's/^max_execution_time =.*/max_execution_time = 360/g' $php_ini_path

echo "-- set date.timezone = $ps_timezone"
sed -i 's/^date.timezone =.*/date.timezone = ${ps_timezone}/g' $php_ini_path

echo "=========  Installing MariaDB ========= "
sudo apt-get install mariadb-server -y

echo "=========  Install Apache2 ========= "
sudo apt-get install apache2 -y

echo "=========  Stop Apache2  ========= "
sudo systemctl stop apache2

echo "=========  Disable Apache2 default site ========= "
sudo a2dissite 000-default.conf

echo "=========  Upload Apache2 VirtualHost configuration ========= "
sudo cat <<DRAMA > $ps_vhost_config

<VirtualHost *:80>
    ServerAdmin admin@$ps_domain
    ServerName $ps_domain
    ServerAlias www.$ps_domain
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/apache2/${ps_domain}-error_log
    CustomLog /var/log/apache2/${ps_domain}-access_log common

    # Redirect all HTTP requests to HTTPS
    RewriteEngine On
    RewriteCond %{HTTPS} !=on
    RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerAdmin admin@$ps_domain
    ServerName $ps_domain
    ServerAlias www.$ps_domain
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/apache2/prestashop-error_log
    CustomLog /var/log/apache2/prestashop-access_log common

    SSLEngine on

    # SSL certificate and private key files
    SSLCertificateFile /etc/ssl/certs/${ps_domain}.crt
    SSLCertificateKeyFile /etc/ssl/private/${ps_domain}.key

    # Optional: SSLCertificateChainFile for intermediate certificates
    # SSLCertificateChainFile /etc/ssl/certs/intermediate.crt

    # Optional: Enable HSTS for improved security (recommended)
    # Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"

    # Optional: Disable SSLv3 and TLSv1 for improved security (recommended)
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1

    # Optional: Enable Perfect Forward Secrecy for improved security (recommended)
    # SSLCipherSuite EECDH+AESGCM:EDH+AESGCM

    # Optional: OCSP Stapling for improved security (recommended)
    # SSLUseStapling on
    # SSLStaplingCache "shmcb:/var/run/ocsp(128KB)"

    # Optional: Enable HTTP/2 for improved performance (if supported)
    # Protocols h2 http/1.1

    # Optional: Configure additional security-related settings as needed
</VirtualHost>

DRAMA

echo "=========  Download Prestashop v$ps_version"
wget -qc $ps_url

echo "=========  Uncompress Prestashop $ps_version ZIP file ========= "
sudo unzip prestashop_${ps_version}.zip -d $ps_dir

echo "=========  Remove default index.html ========= "
sudo rm -f $ps_dir/index.html

echo "=========  Fix ownership of $ps_dir ========= "
sudo chown -R www-data:www-data $ps_dir

echo "=========  Fix directory permissions of $ps_dir ========= "
sudo find $ps_dir -type d -exec chmod 755 {} \;

echo "=========  Fix file permissions of $ps_dir ========= "
sudo find $ps_dir -type f -exec chmod 644 {} \;

echo "=========  Enable Apache2 modules: rewrite, SSL ========= "
sudo a2enmod rewrite
sudo a2enmod ssl

echo "=========  Enable $ps_domain VirtualHost ========= "
sudo a2ensite $ps_domain

echo "========= Disable default Apache sites ========="
sudo a2dissite 000-default
sudo a2dissite default-ssl 

echo "=========  Generate self-signed SSL certificate and key for Apache2 ========= "
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/${ps_domain}.key \
    -out /etc/ssl/certs/${ps_domain}.crt \
    -subj "/C=$ssl_country/ST=$ssl_state/L=$ssl_location/O=$ssl_org/OU=$ssl_ou/CN=$ps_domain"

echo "=========  Enable and start Apache2 ========= "
sudo systemctl enable --now apache2

echo "========= Upload update_parameters.sh ========= "
sudo cat<<PARAM > /root/update_parameters.sh
#!/bin/bash

file=/var/www/html/app/config/parameters.php

echo "-- create backup"
cp -v \$file \${file}_org
echo "-- update DB name"
sed -i 's/$ps_decoy_db/$ps_real_db/g'        \$file
echo "-- update DB user"
sed -i 's/$ps_decoy_db_user/$ps_real_db_user/g'     \$file
echo "-- update DB passwd"
sed -i 's/$ps_decoy_db_pass/$ps_real_db_pass/g'        \$file
echo "-- update DB table prefix"
sed -i 's/ps_/$ps_real_db_prefix/g'                    \$file

PARAM

echo "========= Upload DB management script ==========="
cat <<SCRIPT > /root/create_db_and_user.sh
#!/bin/bash
DB=\$1
USER=\$2
PASS=\$3

mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE \$DB;
CREATE USER '\$USER'@'localhost' IDENTIFIED BY '\$PASS';
GRANT ALL PRIVILEGES ON \$DB.* TO '\$USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "Database:   \$DB"
echo "Username:   \$USER"
echo "Password:   \$PASS"

SCRIPT

echo "========= Upload DB import script ========"
cat <<DBIMPORT > /root/db_import.sh
#!/bin/bash
db_name=$ps_real_db

echo "- import \$db_name"
mysql \$db_name < /home/vagrant/$ps_real_db_sql_dump_file

DBIMPORT

echo "========= Upload img refresh script ========"
cat <<DBIMPORT > /root/refresh_img.sh
#!/bin/bash

echo "- removing old img directory"
rm -rf /var/www/html/img

echo "- unziping img.zip to img directory"
unzip -q /home/vagrant/img.zip -d /var/www/html

echo "- setting permissions"
chown -R www-data: /var/www/html/img

DBIMPORT

echo "========= Set script permissions ========"
scripts="create_db_and_user.sh \
         update_parameters.sh \
         db_import.sh \
         refresh_img.sh"
         
for i in $scripts
do
    echo "--- $i"
    chmod -v 755 /root/$i
done

echo "========= Create decoy DB [ $ps_decoy_db ] =========="
/root/create_db_and_user.sh $ps_decoy_db $ps_decoy_db_user $ps_decoy_db_pass

echo "========= Create production DB [ $ps_real_db ] ========="
/root/create_db_and_user.sh $ps_real_db $ps_real_db_user $ps_real_db_pass

echo "=========  INFO: Upload your img.zip and DB dump to complete the process."
