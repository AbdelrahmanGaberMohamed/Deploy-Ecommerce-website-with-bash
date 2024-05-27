#!/bin/bash
#Script_name: deploy-ecommerce-application.sh
#Purpose: Deply E-Commerce application on single node LAMP STACK
#Author: Abdelrahman Gaber
#Date: 25/05/2024
#Exit Codes:
#   0: Success
#   1: Failed to start one of the following services [firewalld httpd mariadb]
#   2: Firewalld configuration failed
#   3: Site setup isn't correct

##########################################
# Print status messages with color
# Arguments:
#   1- Color: cyan, red, green.
#   2- Message
###########################################
function print_color() {
  no_color='\033[0m'

  case $1 in
    "green") COLOR='\033[0;32m'
    ;;
    "red") COLOR='\033[0;31m'
    ;;
    "cyan") COLOR='\033[0;36m'
    ;;
    "*") COLOR='\033[0m'
    ;;
  esac

  echo -e "${COLOR} $2 ${no_color}"
}
##########################################
# Check Service status
# Arguments:
#   Service Name: httpd, firewalld, etc.
##########################################
function service_status() {
    status=$(sudo systemctl is-active $1)
    if [ $status = "active" ]
    then
        print_color "green" "$1 service is running"
    else
        echo "red" "$1 service isnot active"
        exit 1
    fi
}
##########################################
# Check firewall configuration
# Arguments:
#   Port number: 80, 3306, etc.
##########################################
function firewall_status() {
    port_num=$(sudo firewall-cmd --list-ports)
    #echo ${port_num}
    if [[ $port_num = *$1* ]]
    then
        print_color "green" "Port $1 is allowed on the firewall"
    else
        echo "red" "Port $1 isn't allowed on the firewall"
        exit 2
    fi
}
###############################################
# Check if a given item is on the webpage
# Arguments:
#   1 - Output
#   2 - Item
################################################
function check_item() {
  if [[ $1 = *$2* ]]
  then
    print_color "green" "Item $2 is present on the web page"
  else
    print_color "red" "Item $2 is not present on the web page"
  fi
}
###############################################
#Install required packages
for package_name in firewalld php php-mysqlnd git
do 
    print_color "cyan" "Installing $package_name ...."
    sudo yum install -y $package_name
done

#Start the required services
for service in firewalld httpd
do
    print_color "cyan" "Starting $service service ...."
    sudo systemctl enable --now $service
    status=$(sudo systemctl status $service | grep running | wc -l)
    service_status $service

done

#Configure Firewalld
print_color "cyan" "configuring Firewalld rules ...."
for port_num in 3306 80
do
    firewall-cmd --permanent --zone=public --add-port=${port_num}/tcp
    firewall-cmd --reload
    print_color "cyan" "${port_num}"
    firewall_status $port_num
done

#Install mariadb
print_color "cyan" "Installing MariaDB ...."
cat   > mariadb.repo <<-EOF
# MariaDB 11.3 CentOS repository list - created 2024-05-26 19:22 UTC
# https://mariadb.org/download/
[mariadb]
name = MariaDB
# rpm.mariadb.org is a dynamic mirror if your preferred mirror goes offline. See https://mariadb.org/mirrorbits/ for details.
# baseurl = https://rpm.mariadb.org/11.3/centos/\$releasever/\$basearch
baseurl = https://mariadb.mirror.liquidtelecom.com/yum/11.3/centos/\$releasever/\$basearch
module_hotfixes = 1
# gpgkey = https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB
gpgkey = https://mariadb.mirror.liquidtelecom.com/yum/RPM-GPG-KEY-MariaDB
gpgcheck = 1
EOF

sudo mv mariadb.repo /etc/yum.repos.d/.
sudo yum clean all
sudo yum update -y 
sudo yum install -y MariaDB-server MariaDB-client
sudo systemctl enable --now mariadb
service_status mariadb

#Configure Maria DB DataBase
print_color "cyan" "Setting Up DataBase ..."
cat > setup-db.sql <<-EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
EOF

sudo mysql < setup-db.sql

#Create DB load script
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");

EOF

#Run sql DB load script
sudo mysql < db-load-script.sql

#Configure Apache httpd server
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/
sudo export 
#sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php
sudo sed -i 's/\$link =.*$/\$link = mysqli_connect(localhost, ecomuser, ecompassword, ecomdb)\;/g' /var/www/html/index.php
#Check Items
web_page=$(curl http://localhost)

for item in Laptop Drone VR Watch Phone
do
  check_item "${web_page}" $item
done

exit 0
