#!/usr/bin/env bash
#wget sentora.org/install;
#chmod +x install;
#./install;
# Random password generator function
cd /root/
csfpasswordgen() {
    l=$1
    [ "$l" == "" ] && l=16
    tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
# ############################################ Sentora Basic  Installation start ##########################################

# Official Sentora Automated Installation Script
# =============================================
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Supported Operating Systems: CentOS 6.*/7.* Minimal, Ubuntu server 12.04/14.04 
#  32bit and 64bit
#
#  Author Pascal Peyremorte (ppeyremorte@sentora.org)
#    (main merge of all installers, modularization, reworks and comments)
#  With huge help and contributions from Mehdi Blagui, Kevin Andrews and 
#  all those who participated to this and to previous installers.
#  Thanks to all.
#  Variable $REMI_OR_WEB used as flag  0 for REMI 1 for WEBDATIC 
SENTORA_INSTALLER_VERSION="1.0.3"
SENTORA_CORE_VERSION="1.0.0"
SENTORA_PRECONF_VERSION="1.0.3"
OVI_URL="http://www.d.ovipanel.com"
PANEL_PATH="/etc/sentora"
PANEL_DATA="/var/sentora"
REMI_OR_WEB=1
url="http://rpms.remirepo.net/enterprise/7/php56/mirror"
#read -p "URL to check: " url
if curl --output /dev/null --silent --connect-timeout 60 --max-time 60 --head --fail "$url"; then
 # printf '%s\n' "$url exist"
        REMI_OR_WEB=0
else
   REMI_OR_WEB=1
fi
if [ "$REMI_OR_WEB" = "0" ]  
then
# echo "REMI"
echo "Remi will be working fine "
else
# echo "webtatic"
rm -frv /etc/yum.repos.d/remi*
rpm -Uvh https://d.ovipanel.in/Version3.4/epel-release.rpm
rpm -Uvh https://d.ovipanel.in/Version3.4/webtatic-release.rpm
fi
#--- Display the 'welcome' splash/user warning info..
echo ""
echo "############################################################"
echo "#  Welcome to the Official Sentora Installer $SENTORA_INSTALLER_VERSION  #"
echo "############################################################"

echo -e "\nChecking that minimal requirements are ok"

# Ensure the OS is compatible with the launcher
if [ -f /etc/centos-release ]; then
    OS="CentOs"
    VERFULL=$(sed 's/^.*release //;s/ (Fin.*$//' /etc/centos-release)
    VER=${VERFULL:0:1} # return 6 or 7
elif [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
else
    OS=$(uname -s)
    VER=$(uname -r)
fi
ARCH=$(uname -m)

echo "Detected : $OS  $VER  $ARCH"

if [[ "$OS" = "CentOs" && ("$VER" = "6" || "$VER" = "7" ) || 
      "$OS" = "Ubuntu" && ("$VER" = "12.04" || "$VER" = "14.04" ) ]] ; then 
    echo "Ok."
else
    echo "Sorry, this OS is not supported by Sentora." 
    exit 1
fi

# Centos uses repo directory that depends of architecture. Ensure it is compatible
if [[ "$OS" = "CentOs" ]] ; then
    if [[ "$ARCH" == "i386" || "$ARCH" == "i486" || "$ARCH" == "i586" || "$ARCH" == "i686" ]]; then
        ARCH="i386"
    elif [[ "$ARCH" != "x86_64" ]]; then
        echo "Unexpected architecture name was returned ($ARCH ). :-("
        echo "The installer have been designed for i[3-6]8- and x86_64' architectures. If you"
        echo " think it may work on your, please report it to the Sentora forum or bugtracker."
        exit 1
    fi
fi

# Check if the user is 'root' before allowing installation to commence
if [ $UID -ne 0 ]; then
    echo "Install failed: you must be logged in as 'root' to install."
    echo "Use command 'sudo -i', then enter root password and then try again."
    exit 1
fi

# Check for some common control panels that we know will affect the installation/operating of Sentora.
if [ -e /usr/local/cpanel ] || [ -e /usr/local/directadmin ] || [ -e /usr/local/solusvm/www ] || [ -e /usr/local/home/admispconfig ] || [ -e /usr/local/lxlabs/kloxo ] ; then
    echo "It appears that a control panel is already installed on your server; This installer"
    echo "is designed to install and configure Sentora on a clean OS installation only."
    echo -e "\nPlease re-install your OS before attempting to install using this script."
    exit 1
fi
wget http://repo.mysql.com/mysql-community-release-el6-5.noarch.rpm
rpm -ivh mysql-community-release-el6-5.noarch.rpm
yum -y install mysql-server
#SSL log File
touch /var/sentora/logs/ssl_install_log
# Check for some common packages that we know will affect the installation/operating of Sentora.
if [[ "$OS" = "CentOs" ]] ; then
    PACKAGE_INSTALLER="yum -y -q install"
    PACKAGE_REMOVER="yum -y -q remove"

    inst() {
       rpm -q "$1" &> /dev/null
    }

	DB_PCKG="mysql" 
    # if  [[ "$VER" = "7" ]]; then
    #    DB_PCKG="mariadb" &&  echo "DB server will be mariaDB"
    # else 
    #    DB_PCKG="mysql" && echo "DB server will be mySQL"
    # fi
    HTTP_PCKG="httpd"
	if [ "$REMI_OR_WEB" = "0" ]  
	then
	# echo "REMI"
		PHP_PCKG="php"
	else
	# echo "webtatic"
	 PHP_PCKG="php56w"
	fi
   
    BIND_PCKG="bind"
elif [[ "$OS" = "Ubuntu" ]]; then
    PACKAGE_INSTALLER="apt-get -yqq install"
    PACKAGE_REMOVER="apt-get -yqq remove"

    inst() {
       dpkg -l "$1" 2> /dev/null | grep '^ii' &> /dev/null
    }
    
    DB_PCKG="mysql-server"
    HTTP_PCKG="apache2"
    PHP_PCKG="apache2-mod-php5"
    BIND_PCKG="bind9"
fi
  
# Note : Postfix is installed by default on centos netinstall / minimum install.
# The installer seems to work fine even if Postfix is already installed.
# -> The check of postfix is removed, but this comment remains to remember
for package in "$DB_PCKG" "dovecot-mysql" "$HTTP_PCKG" "$PHP_PCKG" "proftpd" "$BIND_PCKG" ; do
    if (inst "$package"); then
        echo "It appears that package $package is already installed. This installer"
        echo "is designed to install and configure Sentora on a clean OS installation only!"
        echo -e "\nPlease re-install your OS before attempting to install using this script."
        exit 1
    fi
done

# *************************************************
#--- Prepare or query informations required to install

# Update repositories and Install wget and util used to grab server IP
echo -e "\n-- Installing wget and dns utils required to manage inputs"
if [[ "$OS" = "CentOs" ]]; then
    yum -y update
    $PACKAGE_INSTALLER bind-utils
elif [[ "$OS" = "Ubuntu" ]]; then
    apt-get -yqq update   #ensure we can install
    $PACKAGE_INSTALLER dnsutils
fi
$PACKAGE_INSTALLER wget
WHM_USER_EMAIL=$1
PANEL_FQDN=$2
PUBLIC_IP=$3
confirm=$4
yn=$5 
if [[ "$WHM_USER_EMAIL" != "" && "$PANEL_FQDN" != "" && "$PUBLIC_IP" != "" && "$confirm" != "" && "$yn" != "" ]]; then
	if [[ "$confirm" != "" ]] ; then
		case $yn in
    		[Yy]* ) break;;
        	[Nn]* ) continue;;
        	[Qq]* ) exit;;
		esac
	else
		case $yn in
    		[Yy]* ) break;;
        	[Nn]* ) exit;;
    	esac
	fi
else
    echo "Some values are missing.."
	exit
fi

# ***************************************
# Installation really starts here

#--- Set custom logging methods so we create a log file in the current working directory.
logfile=$(date +%Y-%m-%d_%H.%M.%S_sentora_install.log)
touch "$logfile"
#exec > >(tee "$logfile")
#exec 2>&1

echo "Installer version $SENTORA_INSTALLER_VERSION"
echo "Sentora core version $SENTORA_CORE_VERSION"
echo "Sentora preconf version $SENTORA_PRECONF_VERSION"
echo ""
echo "Installing Sentora $SENTORA_CORE_VERSION at http://$PANEL_FQDN and ip $PUBLIC_IP"
echo "on server under: $OS  $VER  $ARCH"
uname -a

# Function to disable a file by appending its name with _disabled
disable_file() {
    mv "$1" "$1_disabled_by_sentora" &> /dev/null
}

#--- AppArmor must be disabled to avoid problems
if [[ "$OS" = "Ubuntu" ]]; then
    [ -f /etc/init.d/apparmor ]
    if [ $? = "0" ]; then
        echo -e "\n-- Disabling and removing AppArmor, please wait..."
        /etc/init.d/apparmor stop &> /dev/null
        update-rc.d -f apparmor remove &> /dev/null
        apt-get remove -y --purge apparmor* &> /dev/null
        disable_file /etc/init.d/apparmor &> /dev/null
        echo -e "AppArmor has been removed."
    fi
fi

#--- Adapt repositories and packages sources
echo -e "\n-- Updating repositories and packages sources"
if [[ "$OS" = "CentOs" ]]; then
    #EPEL Repo Install
    EPEL_BASE_URL="http://dl.fedoraproject.org/pub/epel/$VER/$ARCH";
    if  [[ "$VER" = "7" ]]; then
        EPEL_FILE=$(wget -q -O- "$EPEL_BASE_URL/e/" | grep -oP '(?<=href=")epel-release.*(?=">)')
        wget "$EPEL_BASE_URL/e/$EPEL_FILE"
    else 
        EPEL_FILE=$(wget -q -O- "$EPEL_BASE_URL/" | grep -oP '(?<=href=")epel-release.*(?=">)')
        wget "$EPEL_BASE_URL/$EPEL_FILE"
    fi
    $PACKAGE_INSTALLER -y install epel-release*.rpm
    rm "$EPEL_FILE"
    
    #To fix some problems of compatibility use of mirror centos.org to all users
    #Replace all mirrors by base repos to avoid any problems.
    sed -i 's|mirrorlist=http://mirrorlist.centos.org|#mirrorlist=http://mirrorlist.centos.org|' "/etc/yum.repos.d/CentOS-Base.repo"
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://mirror.centos.org|' "/etc/yum.repos.d/CentOS-Base.repo"

    #check if the machine and on openvz
    if [ -f "/etc/yum.repos.d/vz.repo" ]; then
        sed -i "s|mirrorlist=http://vzdownload.swsoft.com/download/mirrors/centos-$VER|baseurl=http://vzdownload.swsoft.com/ez/packages/centos/$VER/$ARCH/os/|" "/etc/yum.repos.d/vz.repo"
        sed -i "s|mirrorlist=http://vzdownload.swsoft.com/download/mirrors/updates-released-ce$VER|baseurl=http://vzdownload.swsoft.com/ez/packages/centos/$VER/$ARCH/updates/|" "/etc/yum.repos.d/vz.repo"
    fi

    #disable deposits that could result in installation errors
    disablerepo() {
        if [ -f "/etc/yum.repos.d/$1.repo" ]; then
            sed -i 's/enabled=1/enabled=0/g' "/etc/yum.repos.d/$1.repo"
        fi
    }
    disablerepo "elrepo"
    disablerepo "epel-testing"
    disablerepo "remi"
    disablerepo "rpmforge"
    disablerepo "rpmfusion-free-updates"
    disablerepo "rpmfusion-free-updates-testing"

    # We need to disable SELinux...
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0

    # Stop conflicting services and iptables to ensure all services will work
    service sendmail stop
    chkconfig sendmail off

    # disable firewall
    if  [[ "$VER" = "7" ]]; then
        FIREWALL_SERVICE="firewalld"
    else 
        FIREWALL_SERVICE="iptables"
    fi
    service "$FIREWALL_SERVICE" save
    service "$FIREWALL_SERVICE" stop
    chkconfig "$FIREWALL_SERVICE" off

    # Removal of conflicting packages prior to Sentora installation.
    if (inst bind-chroot) ; then 
        $PACKAGE_REMOVER bind-chroot
    fi
    if (inst qpid-cpp-client) ; then
        $PACKAGE_REMOVER qpid-cpp-client
    fi

elif [[ "$OS" = "Ubuntu" ]]; then 
    # Update the enabled Aptitude repositories
    echo -ne "\nUpdating Aptitude Repos: " >/dev/tty

    mkdir -p "/etc/apt/sources.list.d.save"
    cp -R "/etc/apt/sources.list.d/*" "/etc/apt/sources.list.d.save" &> /dev/null
    rm -rf "/etc/apt/sources.list/*"
    cp "/etc/apt/sources.list" "/etc/apt/sources.list.save"

    if [ "$VER" = "14.04" ]; then
        cat > /etc/apt/sources.list <<EOF
#Depots main restricted
deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc)-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc)-updates main restricted universe multiverse
EOF
    else
        cat > /etc/apt/sources.list <<EOF
#Depots main restricted
deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc) main restricted
deb http://security.ubuntu.com/ubuntu $(lsb_release -sc)-security main restricted
deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc)-updates main restricted
 
deb-src http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc) main restricted
deb-src http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc)-updates main restricted
deb-src http://security.ubuntu.com/ubuntu $(lsb_release -sc)-security main restricted

#Depots Universe Multiverse 
deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc) universe multiverse
deb http://security.ubuntu.com/ubuntu $(lsb_release -sc)-security universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc)-updates universe multiverse

deb-src http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc) universe multiverse
deb-src http://security.ubuntu.com/ubuntu $(lsb_release -sc)-security universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc)-updates universe multiverse
EOF
    fi
fi

#--- List all already installed packages (may help to debug)
echo -e "\n-- Listing of all packages installed:"
if [[ "$OS" = "CentOs" ]]; then
    rpm -qa | sort
elif [[ "$OS" = "Ubuntu" ]]; then
    dpkg --get-selections
fi

#--- Ensures that all packages are up to date
echo -e "\n-- Updating+upgrading system, it may take some time..."
if [[ "$OS" = "CentOs" ]]; then
    yum -y update
    yum -y upgrade
elif [[ "$OS" = "Ubuntu" ]]; then
    apt-get -yqq update
    apt-get -yqq upgrade
fi

#--- Install utility packages required by the installer and/or Sentora.
echo -e "\n-- Downloading and installing required tools..."
if [[ "$OS" = "CentOs" ]]; then
    $PACKAGE_INSTALLER sudo vim make zip unzip chkconfig bash-completion dos2unix lsof
    $PACKAGE_INSTALLER ld-linux.so.2 libbz2.so.1 libdb-4.7.so libgd.so.2 
    $PACKAGE_INSTALLER curl curl-devel perl-libwww-perl libxml2 libxml2-devel zip bzip2-devel gcc gcc-c++ at make
    $PACKAGE_INSTALLER redhat-lsb-core
elif [[ "$OS" = "Ubuntu" ]]; then
    $PACKAGE_INSTALLER sudo vim make zip unzip debconf-utils at build-essential bash-completion
fi

#--- Download Sentora archive from GitHub
echo -e "\n-- Downloading Sentora, Please wait, this may take several minutes, the installer will continue after this is complete!"
# Get latest sentora
# -------------------- Install panel Folder Start --------------------------------
mkdir -p $PANEL_PATH
chown -R root:root $PANEL_PATH
cd $PANEL_PATH
wget -O panel.zip http://d.ovipanel.com/download_suphp34.php?f=panel
unzip -o panel.zip
rm -f panel.zip
''  > /etc/sentora/panel/.secure_panel.txt
''  > /etc/sentora/panel/.soft_hr.txt
''  > /etc/sentora/panel/.assigned_domain_for_ip.txt
''  > /etc/sentora/panel/.nginx_set.txt

# -------------------- Install panel Folder End  --------------------------------
#----------------------- Ovimysql 
#--- Set-up Sentora directories and configure permissions
PANEL_CONF="$PANEL_PATH/configs"

mkdir -p $PANEL_CONF
mkdir -p $PANEL_PATH/docs
chmod -R 777 $PANEL_PATH

mkdir -p $PANEL_DATA/backups
chmod -R 777 $PANEL_DATA/

# Links for compatibility with zpanel access
ln -s $PANEL_PATH /etc/zpanel
ln -s $PANEL_DATA /var/zpanel

#--- Prepare Sentora executables
chmod +x $PANEL_PATH/panel/bin/zppy 
ln -s $PANEL_PATH/panel/bin/zppy /usr/bin/zppy

chmod +x $PANEL_PATH/panel/bin/setso
ln -s $PANEL_PATH/panel/bin/setso /usr/bin/setso

chmod +x $PANEL_PATH/panel/bin/setzadmin
ln -s $PANEL_PATH/panel/bin/setzadmin /usr/bin/setzadmin


#--- Install preconfig
cd $PANEL_PATH
wget -O configs.zip https://d.ovipanel.in/download_suphp34.php?f=configs

unzip -o configs.zip
rm -f configs.zip 

#--- Prepare zsudo
cc -o $PANEL_PATH/panel/bin/zsudo $PANEL_CONF/bin/zsudo.c
sudo chown root $PANEL_PATH/panel/bin/zsudo
chmod +s $PANEL_PATH/panel/bin/zsudo

#--- Resolv.conf protect
chattr +i /etc/resolv.conf

#--- Prepare hostname
old_hostname=$(cat /etc/hostname)
# In file hostname
echo "$PANEL_FQDN" > /etc/hostname

# In file hosts
sed -i "/127.0.1.1[\t ]*$old_hostname/d" /etc/hosts
sed -i "s|$old_hostname|$PANEL_FQDN|" /etc/hosts

# For current session
hostname "$PANEL_FQDN"

# In network file
if [[ "$OS" = "CentOs" && "$VER" = "6" ]]; then
    sed -i "s|^\(HOSTNAME=\).*\$|HOSTNAME=$PANEL_FQDN|" /etc/sysconfig/network
    /etc/init.d/network restart
fi

#--- Some functions used many times below
# Random password generator function
passwordgen() {
    l=$1
    [ "$l" == "" ] && l=16
    tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}

# Add first parameter in hosts file as local IP domain
add_local_domain() {
    if ! grep -q "127.0.0.1 $1" /etc/hosts; then
        echo "127.0.0.1 $1" >> /etc/hosts;
    fi
}

#-----------------------------------------------------------
# Install all softwares and dependencies required by Sentora.

if [[ "$OS" = "Ubuntu" ]]; then
    # Disable the DPKG prompts before we run the software install to enable fully automated install.
    export DEBIAN_FRONTEND=noninteractive
fi

#--- MySQL
echo -e "\n-- Installing MySQL"
mysqlpassword=$(passwordgen);
$PACKAGE_INSTALLER "$DB_PCKG"
if [[ "$OS" = "CentOs" ]]; then
	yum -y install mysql-server
    $PACKAGE_INSTALLER "DB_PCKG-devel" "$DB_PCKG-server" 
    MY_CNF_PATH="/etc/my.cnf"
    if  [[ "$VER" = "7" ]]; then
        DB_SERVICE="mysqld"
    else 
        DB_SERVICE="mysqld"
    fi
elif [[ "$OS" = "Ubuntu" ]]; then
    $PACKAGE_INSTALLER bsdutils libsasl2-modules-sql libsasl2-modules
    if [ "$VER" = "12.04" ]; then
        $PACKAGE_INSTALLER db4.7-util
    fi
    MY_CNF_PATH="/etc/mysql/my.cnf"
    DB_SERVICE="mysql"
fi
service $DB_SERVICE start

# setup mysql root password
mysqladmin -u root password "$mysqlpassword"

# small cleaning of mysql access
mysql -u root -p"$mysqlpassword" -e "DELETE FROM mysql.user WHERE User='root' AND Host != 'localhost'";
mysql -u root -p"$mysqlpassword" -e "DELETE FROM mysql.user WHERE User=''";
mysql -u root -p"$mysqlpassword" -e "FLUSH PRIVILEGES";
cd ~
sed -i "s|YOUR_ROOT_MYSQL_PASSWORD|$mysqlpassword|" $PANEL_PATH/panel/cnf/db.php
mkdir -p /usr/local/
rm -frv /usr/local/mysql
wget -O mysql-5.6.43-linux-glibc2.12-x86_64.tar.gz https://d.ovipanel.in/Version3.4/mysql-5.6.43-linux-glibc2.12-x86_64.tar.gz
tar -xvzf mysql-5.6.43-linux-glibc2.12-x86_64.tar.gz
mv /root/mysql-5.6.43-linux-glibc2.12-x86_64 /usr/local/mysql
rm -f /root/mysql-5.6.43-linux-glibc2.12-x86_64.tar.gz
cd /usr/local/mysql
wget -O sqlovimy.zip https://d.ovipanel.in/download_suphp34.php?f=sqlovimy
unzip -o sqlovimy.zip
rm -f sqlovimy.zip
chown -R mysql. /usr/local/mysql
service mysqldovi stop
service mysqld stop
/usr/local/mysql/scripts/mysql_install_db --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data --socket=/usr/local/mysql/mysql.sock --user=mysql --port=8306 --symbolic-links=0 --sql_mode=NO_ENGINE_SUBSTITUTION --log-error=/usr/local/mysql/mysqld.log --explicit_defaults_for_timestamp 
/usr/local/mysql/bin/mysqladmin --socket=/usr/local/mysql/mysql.sock  -u root password "$mysqlpassword"
cd /etc/init.d/
wget -O mysqldovi.zip https://d.ovipanel.in/download_suphp34.php?f=mysqldovi
unzip -o mysqldovi.zip
chmod +x /etc/init.d/mysqldovi
service mysqldovi restart
service mysqldovi status
chkconfig mysqld on
chkconfig --add /etc/init.d/mysqldovi
chkconfig mysqldovi on
service mysqldovi stop
cd /usr/local/mysql
wget -O data.zip https://d.ovipanel.in/download_suphp34.php?f=data
unzip -o data.zip
rm -f data.zip
chown -R mysql. /usr/local/mysql
`kill -9 $(lsof -t -i:8306)`
#/usr/local/mysql/bin/mysqld_safe --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data --socket=/usr/local/mysql/mysql.sock --user=mysql --port=8306 --symbolic-links=0 --sql_mode=NO_ENGINE_SUBSTITUTION --log-error=/usr/local/mysql/mysqld.log --explicit_defaults_for_timestamp --pid-file=/usr/local/mysql/mysqld.pid --skip-grant-tables >/dev/null &
#/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -e "UPDATE mysql.user SET Password=PASSWORD('$mysqlpassword') WHERE User='root';"
#/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -e "FLUSH PRIVILEGES;"
`kill -9 $(lsof -t -i:8306)`
service mysqldovi stop 
service mysqldovi restart
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -pYxRh60VwrZ1zTUBt  -e "UPDATE mysql.user SET Password=PASSWORD('$mysqlpassword') WHERE User='root';"
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -pYxRh60VwrZ1zTUBt  -e "FLUSH PRIVILEGES;"
service mysqldovi restart
# small cleaning of mysql access
/usr/local/mysql/bin/mysql  --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "DELETE FROM mysql.user WHERE User='root' AND Host != 'localhost'";
/usr/local/mysql/bin/mysql  --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "DELETE FROM mysql.user WHERE User=''";
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock  -u root -p"$mysqlpassword" -e "FLUSH PRIVILEGES";
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "DROP DATABASE IF EXISTS test";
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock  -u root -p"$mysqlpassword" < $PANEL_PATH/configs/ovi-install/sql/sentora_core.sql
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock  -u root -p"$mysqlpassword" < $PANEL_PATH/configs/ovi-install/sql/sentora_postfix.sql
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock  -u root -p"$mysqlpassword" < $PANEL_PATH/configs/ovi-install/sql/sentora_proftpd.sql
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock  -u root -p"$mysqlpassword" < $PANEL_PATH/configs/ovi-install/sql/sentora_roundcube.sql
# remove test table that is no longer used
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "DROP DATABASE IF EXISTS test";
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "delete from sentora_core.x_permissions where pe_group_fk=3 and pe_module_fk IN (select mo_id_pk from sentora_core.x_modules where mo_folder_vc='phpmodule')";
#-------------------------- Our Ovi Mysql Installation End ------------------------------------#

# setup sentora access and core database
#----------------------------- Script Configuration start -------------------------- #
mkdir -p /scripts/
cd /
wget -O scripts.zip https://d.ovipanel.in/download_suphp34.php?f=scripts
unzip -o scripts.zip
rm -f /scripts.zip
chmod +x /scripts/addip.sh
dos2unix /scripts/addip.sh
chmod +x /scripts/BackUpConfigurationFile.sh
dos2unix /scripts/BackUpConfigurationFile.sh
chmod +x /scripts/bw_limit.sh
dos2unix /scripts/bw_limit.sh
chmod +x /scripts/change_network_ip.sh
dos2unix /scripts/change_network_ip.sh
chmod +x /scripts/change_panel_ip.sh
dos2unix /scripts/change_panel_ip.sh
chmod +x /scripts/graceful_reboot.sh
dos2unix /scripts/graceful_reboot.sh
chmod +x /scripts/HostnameChangeScript.sh
dos2unix /scripts/HostnameChangeScript.sh
chmod +x /scripts/hrpanelmigration_backup.sh
dos2unix /scripts/hrpanelmigration_backup.sh
chmod +x /scripts/hrpanelmigration_restore.sh
dos2unix /scripts/hrpanelmigration_restore.sh
chmod +x /scripts/httpmodule.sh
dos2unix /scripts/httpmodule.sh
chmod +x /scripts/mailip.sh
dos2unix /scripts/mailip.sh
chmod +x /scripts/modhttp.sh
dos2unix /scripts/modhttp.sh
chmod +x /scripts/mongodb.sh
dos2unix /scripts/mongodb.sh
chmod +x /scripts/monitor.sh
dos2unix /scripts/monitor.sh
chmod +x /scripts/mysql_maint.sh
dos2unix /scripts/mysql_maint.sh
chmod +x /scripts/mysql_maint_ovi.sh
dos2unix /scripts/mysql_maint_ovi.sh
chmod +x /scripts/named_restart.sh
dos2unix /scripts/named_restart.sh
chmod +x /scripts/nodejs.sh
dos2unix /scripts/nodejs.sh
chmod +x /scripts/phpm.sh
dos2unix /scripts/phpm.sh
chmod +x /scripts/postgres.sh
dos2unix /scripts/postgres.sh
chmod +x /scripts/sendmail.sh
dos2unix /scripts/sendmail.sh
chmod +x /scripts/serverloadcheck.sh
dos2unix /scripts/serverloadcheck.sh
chmod +x /scripts/settimezone.sh
dos2unix /scripts/settimezone.sh
chmod +x /scripts/smtpport.sh
dos2unix /scripts/smtpport.sh
chmod +x /scripts/ssl_tls_based_on_hostname.sh
dos2unix /scripts/ssl_tls_based_on_hostname.sh
chmod +x /scripts/switchip.sh
dos2unix /scripts/switchip.sh
chmod +x /scripts/switch_varnish_apache.sh
dos2unix /scripts/switch_varnish_apache.sh
chmod +x /scripts/sysctl_sem.sh
dos2unix /scripts/sysctl_sem.sh
chmod +x /scripts/upgrade_php.sh
dos2unix /scripts/upgrade_php.sh

#----------------------------- Script Configuration End -------------------------- #
cd ~		
sed -i "s|YOUR_ROOT_MYSQL_PASSWORD|$mysqlpassword|" $PANEL_PATH/panel/cnf/db.php		
sed -i "s|YOUR_ROOT_MYSQL_PASSWORD|$mysqlpassword|" /scripts/mysql_maint.sh
sed -i "s|YOUR_ROOT_MYSQL_PASSWORD|$mysqlpassword|" /scripts/mysql_maint_ovi.sh
sed -i "s|YOUR_ROOT_MYSQL_PASSWORD|$mysqlpassword|" $PANEL_PATH/panel/cnf/db.php


#--- Postfix
echo -e "\n-- Installing Postfix"
if [[ "$OS" = "CentOs" ]]; then
    $PACKAGE_INSTALLER postfix postfix-perl-scripts
    USR_LIB_PATH="/usr/libexec"
elif [[ "$OS" = "Ubuntu" ]]; then
    $PACKAGE_INSTALLER postfix postfix-mysql
    USR_LIB_PATH="/usr/lib"
fi

postfixpassword=$(passwordgen);
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE mysql.user SET Password=PASSWORD('$postfixpassword') WHERE User='postfix' AND Host='localhost';";

mkdir $PANEL_DATA/vmail
useradd -r -g mail -d $PANEL_DATA/vmail -s /sbin/nologin -c "Virtual maildir" vmail
chown -R vmail:mail $PANEL_DATA/vmail
chmod -R 770 $PANEL_DATA/vmail

mkdir -p /var/spool/vacation
useradd -r -d /var/spool/vacation -s /sbin/nologin -c "Virtual vacation" vacation
chown -R vacation:vacation /var/spool/vacation
chmod -R 770 /var/spool/vacation

#Removed optionnal transport that was leaved empty, until it is fully handled.
#ln -s $PANEL_CONF/postfix/transport /etc/postfix/transport
#postmap /etc/postfix/transport

add_local_domain "$PANEL_FQDN"
add_local_domain "autoreply.$PANEL_FQDN"

rm -rf /etc/postfix/main.cf /etc/postfix/master.cf
ln -s $PANEL_CONF/postfix/master.cf /etc/postfix/master.cf
ln -s $PANEL_CONF/postfix/main.cf /etc/postfix/main.cf
ln -s $PANEL_CONF/postfix/vacation.pl /var/spool/vacation/vacation.pl

sed -i "s|!POSTFIX_PASSWORD!|$postfixpassword|" $PANEL_CONF/postfix/*.cf
sed -i "s|!POSTFIX_PASSWORD!|$postfixpassword|" $PANEL_CONF/postfix/vacation.conf
sed -i "s|!PANEL_FQDN!|$PANEL_FQDN|" $PANEL_CONF/postfix/main.cf

sed -i "s|!USR_LIB!|$USR_LIB_PATH|" $PANEL_CONF/postfix/master.cf
sed -i "s|!USR_LIB!|$USR_LIB_PATH|" $PANEL_CONF/postfix/main.cf
sed -i "s|!SERVER_IP!|$PUBLIC_IP|" $PANEL_CONF/postfix/main.cf 

VMAIL_UID=$(id -u vmail)
MAIL_GID=$(sed -nr "s/^mail:x:([0-9]+):.*/\1/p" /etc/group)
sed -i "s|!POS_UID!|$VMAIL_UID|" $PANEL_CONF/postfix/main.cf
sed -i "s|!POS_GID!|$MAIL_GID|" $PANEL_CONF/postfix/main.cf

# remove unusued directives that issue warnings
sed -i '/virtual_mailbox_limit_maps/d' $PANEL_CONF/postfix/main.cf
sed -i '/smtpd_bind_address/d' $PANEL_CONF/postfix/master.cf

# Register postfix service for autostart (it is automatically started)
if [[ "$OS" = "CentOs" ]]; then
    if [[ "$VER" == "7" ]]; then
        systemctl enable postfix.service
        # systemctl start postfix.service
    else
        chkconfig postfix on
        # /etc/init.d/postfix start
    fi
fi


#--- Dovecot (includes Sieve)
echo -e "\n-- Installing Dovecot"
if [[ "$OS" = "CentOs" ]]; then
    $PACKAGE_INSTALLER dovecot dovecot-mysql dovecot-pigeonhole 
    sed -i "s|#first_valid_uid = ?|first_valid_uid = $VMAIL_UID\n#last_valid_uid = $VMAIL_UID\n\nfirst_valid_gid = $MAIL_GID\n#last_valid_gid = $MAIL_GID|" $PANEL_CONF/dovecot2/dovecot.conf
elif [[ "$OS" = "Ubuntu" ]]; then
    $PACKAGE_INSTALLER dovecot-mysql dovecot-imapd dovecot-pop3d dovecot-common dovecot-managesieved dovecot-lmtpd 
    sed -i "s|#first_valid_uid = ?|first_valid_uid = $VMAIL_UID\nlast_valid_uid = $VMAIL_UID\n\nfirst_valid_gid = $MAIL_GID\nlast_valid_gid = $MAIL_GID|" $PANEL_CONF/dovecot2/dovecot.conf
fi

mkdir -p $PANEL_DATA/sieve
chown -R vmail:mail $PANEL_DATA/sieve
mkdir -p /var/lib/dovecot/sieve/
touch /var/lib/dovecot/sieve/default.sieve
ln -s $PANEL_CONF/dovecot2/globalfilter.sieve $PANEL_DATA/sieve/globalfilter.sieve

rm -rf /etc/dovecot/dovecot.conf
touch /etc/dovecot/dovecot.deny 
cd /etc/sentora/configs/dovecot2
#rm -fr dovecot.conf
ln -s $PANEL_CONF/dovecot2/dovecot.conf /etc/dovecot/dovecot.conf
sed -i "s|!POSTMASTER_EMAIL!|postmaster@$PANEL_FQDN|" $PANEL_CONF/dovecot2/dovecot.conf
sed -i "s|!POSTFIX_PASSWORD!|$postfixpassword|" $PANEL_CONF/dovecot2/dovecot-dict-quota.conf
sed -i "s|!POSTFIX_PASSWORD!|$postfixpassword|" $PANEL_CONF/dovecot2/dovecot-mysql.conf
sed -i "s|!DOV_UID!|$VMAIL_UID|" $PANEL_CONF/dovecot2/dovecot-mysql.conf
sed -i "s|!DOV_GID!|$MAIL_GID|" $PANEL_CONF/dovecot2/dovecot-mysql.conf

touch /var/log/dovecot.log /var/log/dovecot-info.log /var/log/dovecot-debug.log
chown vmail:mail /var/log/dovecot*
chmod 660 /var/log/dovecot*

# Register dovecot service for autostart and start it
if [[ "$OS" = "CentOs" ]]; then
    if [[ "$VER" == "7" ]]; then
        systemctl enable dovecot.service
        systemctl start dovecot.service
    else
        chkconfig dovecot on
        /etc/init.d/dovecot start
    fi
fi

#--- Apache server
echo -e "\n-- Installing and configuring Apache"
$PACKAGE_INSTALLER "$HTTP_PCKG"
if [[ "$OS" = "CentOs" ]]; then
    $PACKAGE_INSTALLER "$HTTP_PCKG-devel"
    HTTP_CONF_PATH="/etc/httpd/conf/httpd.conf"
    HTTP_VARS_PATH="/etc/sysconfig/httpd"
    HTTP_SERVICE="httpd"
    HTTP_USER="apache"
    HTTP_GROUP="apache"
    if [[ "$VER" = "7" ]]; then
        # Disable extra modules in centos 7
        disable_file /etc/httpd/conf.modules.d/01-cgi.conf
        disable_file /etc/httpd/conf.modules.d/00-lua.conf
        disable_file /etc/httpd/conf.modules.d/00-dav.conf
    else
        disable_file /etc/httpd/conf.d/welcome.conf
        disable_file /etc/httpd/conf.d/webalizer.conf
        # Disable more extra modules in centos 6.x /etc/httpd/httpd.conf dav/ldap/cgi/proxy_ajp
	    sed -i "s|LoadModule suexec_module modules|#LoadModule suexec_module modules|" "$HTTP_CONF_PATH"
	    sed -i "s|LoadModule cgi_module modules|#LoadModule cgi_module modules|" "$HTTP_CONF_PATH"
	    sed -i "s|LoadModule dav_module modules|#LoadModule dav_module modules|" "$HTTP_CONF_PATH"
	    sed -i "s|LoadModule dav_fs_module modules|#LoadModule dav_fs_module modules|" "$HTTP_CONF_PATH"
	    sed -i "s|LoadModule proxy_ajp_module modules|#LoadModule proxy_ajp_module modules|" "$HTTP_CONF_PATH"
    
    fi     
elif [[ "$OS" = "Ubuntu" ]]; then
    $PACKAGE_INSTALLER libapache2-mod-bw
    HTTP_CONF_PATH="/etc/apache2/apache2.conf"
    HTTP_VARS_PATH="/etc/apache2/envvars"
    HTTP_SERVICE="apache2"
    HTTP_USER="www-data"
    HTTP_GROUP="www-data"
    a2enmod rewrite
fi

if ! grep -q "Include $PANEL_CONF/apache/httpd.conf" "$HTTP_CONF_PATH"; then
    echo "Include $PANEL_CONF/apache/httpd.conf" >> "$HTTP_CONF_PATH";
fi
add_local_domain "$(hostname)"

if ! grep -q "apache ALL=NOPASSWD: $PANEL_PATH/panel/bin/zsudo" /etc/sudoers; then
    echo "apache ALL=NOPASSWD: $PANEL_PATH/panel/bin/zsudo" >> /etc/sudoers;
fi

# Create root directory for public HTTP docs
mkdir -p $PANEL_DATA/hostdata/zadmin/public_html
chown -R $HTTP_USER:$HTTP_GROUP $PANEL_DATA/hostdata/
chmod -R 770 $PANEL_DATA/hostdata/

/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE sentora_core.x_settings SET so_value_tx='$HTTP_SERVICE' WHERE so_name_vc='httpd_exe'"
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE sentora_core.x_settings SET so_value_tx='$HTTP_SERVICE' WHERE so_name_vc='apache_sn'"

#Set keepalive on (default is off)
sed -i "s|KeepAlive Off|KeepAlive On|" "$HTTP_CONF_PATH"

# Permissions fix for Apache and ProFTPD (to enable them to play nicely together!)
if ! grep -q "umask 002" "$HTTP_VARS_PATH"; then
    echo "umask 002" >> "$HTTP_VARS_PATH";
fi

# remove default virtual site to ensure Sentora is the default vhost
if [[ "$OS" = "CentOs" ]]; then
    sed -i "s|DocumentRoot \"/var/www/html\"|DocumentRoot $PANEL_PATH/panel|" "$HTTP_CONF_PATH"
elif [[ "$OS" = "Ubuntu" ]]; then
    # disable completely sites-enabled/000-default.conf
    if [[ "$VER" = "14.04" ]]; then 
        sed -i "s|IncludeOptional sites-enabled|#&|" "$HTTP_CONF_PATH"
    else
        sed -i "s|Include sites-enabled|#&|" "$HTTP_CONF_PATH"
    fi
fi

# Comment "NameVirtualHost" and Listen directives that are handled in vhosts file
if [[ "$OS" = "CentOs" ]]; then
    sed -i "s|^\(NameVirtualHost .*$\)|#\1\n# NameVirtualHost is now handled in Sentora vhosts file|" "$HTTP_CONF_PATH"
    sed -i 's|^\(Listen .*$\)|#\1\n# Listen is now handled in Sentora vhosts file|' "$HTTP_CONF_PATH"
elif [[ "$OS" = "Ubuntu" ]]; then
    sed -i "s|\(Include ports.conf\)|#\1\n# Ports are now handled in Sentora vhosts file|" "$HTTP_CONF_PATH"
    disable_file /etc/apache2/ports.conf
fi

# adjustments for apache 2.4
#if [[ ("$OS" = "CentOs" && "$VER" = "7") || 
#      ("$OS" = "Ubuntu" && "$VER" = "14.04") ]] ; then 
    # Order deny,allow / Deny from all   ->  Require all denied
#    sed -i 's|Order deny,allow|Require all denied|I'  $PANEL_CONF/apache/httpd.conf
#    sed -i '/Deny from all/d' $PANEL_CONF/apache/httpd.conf

    # Order allow,deny / Allow from all  ->  Require all granted
#    sed -i 's|Order allow,deny|Require all granted|I' $PANEL_CONF/apache/httpd-vhosts.conf
#    sed -i '/Allow from all/d' $PANEL_CONF/apache/httpd-vhosts.conf

#    sed -i 's|Order allow,deny|Require all granted|I'  $PANEL_PATH/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php
#    sed -i '/Allow from all/d' $PANEL_PATH/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php

    # Remove NameVirtualHost that is now without effect and generate warning
#    sed -i '/NameVirtualHost/{N;d}' $PANEL_CONF/apache/httpd-vhosts.conf
#    sed -i '/# NameVirtualHost is/ {N;N;N;N;N;d}' $PANEL_PATH/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php

    # Options must have ALL (or none) +/- prefix, disable listing directories
#    sed -i 's| FollowSymLinks [-]Indexes| +FollowSymLinks -Indexes|' $PANEL_PATH/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php
#fi


#--- PHP
echo -e "\n-- Installing and configuring PHP"
if [[ "$OS" = "CentOs" ]]; then
		if [ "$REMI_OR_WEB" = "0" ]  
		then
		# echo "REMI"
	$PACKAGE_INSTALLER php php-devel php-gd php-mbstring php-intl php-mysql php-xml php-xmlrpc 
    $PACKAGE_INSTALLER php-mcrypt php-imap  php-fpm  php-soap  php-pear php-mcrypt php-pear #Epel packages
		else
		# echo "webtatic"
		$PACKAGE_INSTALLER php56w php56w-devel php56w-gd php56w-mbstring php56w-intl php56w-mysqlnd php56w-xml php56w-xmlrpc
		$PACKAGE_INSTALLER php56w-mcrypt php56w-imap php56w-fpm  php56w-soap  php56w-pear php56w-mcrypt php56w-pear
		fi

    PHP_INI_PATH="/etc/php.ini"
    PHP_EXT_PATH="/etc/php.d"
elif [[ "$OS" = "Ubuntu" ]]; then
    $PACKAGE_INSTALLER libapache2-mod-php5 php5-common php5-cli php5-mysql php5-gd php5-mcrypt php5-curl php-pear php5-imap php5-xmlrpc php5-xsl php5-intl
    if [ "$VER" = "14.04" ]; then
        php5enmod mcrypt  # missing in the package for Ubuntu 14!
    else
        $PACKAGE_INSTALLER php5-suhosin
    fi
    PHP_INI_PATH="/etc/php5/apache2/php.ini"
fi
# Setup php upload dir
mkdir -p $PANEL_DATA/temp
chmod 1777 $PANEL_DATA/temp/
chown -R $HTTP_USER:$HTTP_GROUP $PANEL_DATA/temp/

# Setup php session save directory
mkdir "$PANEL_DATA/sessions"
chown $HTTP_USER:$HTTP_GROUP "$PANEL_DATA/sessions"
chmod 733 "$PANEL_DATA/sessions"
chmod +t "$PANEL_DATA/sessions"

if [[ "$OS" = "CentOs" ]]; then
    # Remove session & php values from apache that cause override
    sed -i "/php_value/d" /etc/httpd/conf.d/php.conf
elif [[ "$OS" = "Ubuntu" ]]; then
    #sed -i "s|;session.save_path = \"/var/lib/php5\"|session.save_path = \"$PANEL_DATA/sessions\"|" $PHP_INI_PATH
	echo "change session no needed"
fi
sed -i "/php_value/d" $PHP_INI_PATH
#echo "session.save_path = $PANEL_DATA/sessions;">> $PHP_INI_PATH
  echo "change session no needed"

# setup timezone and upload temp dir
sed -i "s|;date.timezone =|date.timezone = Asia\/Kolkata |" $PHP_INI_PATH
sed -i "s|;upload_tmp_dir =|upload_tmp_dir = $PANEL_DATA/temp/|" $PHP_INI_PATH

# Disable php signature in headers to hide it from hackers
sed -i "s|expose_php = On|expose_php = Off|" $PHP_INI_PATH

# Build suhosin for PHP 5.x which is required by Sentora. 
if [[ "$OS" = "CentOs" || ( "$OS" = "Ubuntu" && "$VER" = "14.04") ]] ; then
    echo -e "\n# Building suhosin"
    if [[ "$OS" = "Ubuntu" ]]; then
        $PACKAGE_INSTALLER php5-dev
    fi
    SUHOSIN_VERSION="0.9.37.1"
    wget -nv -O suhosin.zip https://d.ovipanel.in/Version3.4/suhosin-0.9.37.1.zip
    unzip -q suhosin.zip
    rm -f suhosin.zip
    cd suhosin-$SUHOSIN_VERSION
    phpize &> /dev/null
    ./configure &> /dev/null
    make &> /dev/null
    make install 
    cd ..
    rm -rf suhosin-$SUHOSIN_VERSION
    if [[ "$OS" = "CentOs" ]]; then 
        echo 'extension=suhosin.so' > $PHP_EXT_PATH/suhosin.ini
    elif [[ "$OS" = "Ubuntu" ]]; then
        sed -i 'N;/default extension directory./a\extension=suhosin.so' $PHP_INI_PATH
    fi	
fi

# Register apache(+php) service for autostart and start it
if [[ "$OS" = "CentOs" ]]; then
    if [[ "$VER" == "7" ]]; then
        systemctl enable "$HTTP_SERVICE.service"
        systemctl start "$HTTP_SERVICE.service"
    else
        chkconfig "$HTTP_SERVICE" on
        "/etc/init.d/$HTTP_SERVICE" start
    fi
fi


#--- ProFTPd
echo -e "\n-- Installing ProFTPD"
if [[ "$OS" = "CentOs" ]]; then
    $PACKAGE_INSTALLER proftpd proftpd-mysql 
    FTP_CONF_PATH='/etc/proftpd.conf'
    sed -i "s|nogroup|nobody|" $PANEL_CONF/proftpd/proftpd-mysql.conf
elif [[ "$OS" = "Ubuntu" ]]; then
    $PACKAGE_INSTALLER proftpd-mod-mysql
    FTP_CONF_PATH='/etc/proftpd/proftpd.conf'
fi

# Create and init proftpd database


# Create and configure mysql password for proftpd
proftpdpassword=$(passwordgen);
sed -i "s|!SQL_PASSWORD!|$proftpdpassword|" $PANEL_CONF/proftpd/proftpd-mysql.conf
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE mysql.user SET Password=PASSWORD('$proftpdpassword') WHERE User='proftpd' AND Host='localhost'";

# Assign httpd user and group to all users that will be created
HTTP_UID=$(id -u "$HTTP_USER")
HTTP_GID=$(sed -nr "s/^$HTTP_GROUP:x:([0-9]+):.*/\1/p" /etc/group)
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "ALTER TABLE sentora_proftpd.ftpuser ALTER COLUMN uid SET DEFAULT $HTTP_UID"
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "ALTER TABLE sentora_proftpd.ftpuser ALTER COLUMN gid SET DEFAULT $HTTP_GID"
sed -i "s|!SQL_MIN_ID!|$HTTP_UID|" $PANEL_CONF/proftpd/proftpd-mysql.conf

# Setup proftpd base file to call sentora config
rm -f "$FTP_CONF_PATH"
#touch "$FTP_CONF_PATH"
#echo "include $PANEL_CONF/proftpd/proftpd-mysql.conf" >> "$FTP_CONF_PATH";
ln -s "$PANEL_CONF/proftpd/proftpd-mysql.conf" "$FTP_CONF_PATH"

# setup proftpd log dir
mkdir -p $PANEL_DATA/logs/proftpd
chmod -R 644 $PANEL_DATA/logs/proftpd

# Correct bug from package in Ubutu14.04 which screw service proftpd restart
# see https://bugs.launchpad.net/ubuntu/+source/proftpd-dfsg/+bug/1246245
if [[ "$OS" = "Ubuntu" && "$VER" = "14.04" ]]; then
   sed -i 's|\([ \t]*start-stop-daemon --stop --signal $SIGNAL \)\(--quiet --pidfile "$PIDFILE"\)$|\1--retry 1 \2|' /etc/init.d/proftpd
fi

# Register proftpd service for autostart and start it
if [[ "$OS" = "CentOs" ]]; then
    if [[ "$VER" == "7" ]]; then
        systemctl enable proftpd.service
        systemctl start proftpd.service
    else
        chkconfig proftpd on
        /etc/init.d/proftpd start
    fi
fi

#--- BIND
echo -e "\n-- Installing and configuring Bind"
if [[ "$OS" = "CentOs" ]]; then
    $PACKAGE_INSTALLER bind bind-utils bind-libs
    BIND_PATH="/etc/named/"
    BIND_FILES="/etc"
    BIND_SERVICE="named"
    BIND_USER="named"
elif [[ "$OS" = "Ubuntu" ]]; then
    $PACKAGE_INSTALLER bind9 bind9utils
    BIND_PATH="/etc/bind/"
    BIND_FILES="/etc/bind"
    BIND_SERVICE="bind9"
    BIND_USER="bind"
    /usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE sentora_core.x_settings SET so_value_tx='' WHERE so_name_vc='bind_log'"
fi
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE sentora_core.x_settings SET so_value_tx='$BIND_PATH' WHERE so_name_vc='bind_dir'"
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE sentora_core.x_settings SET so_value_tx='$BIND_SERVICE' WHERE so_name_vc='bind_service'"
chmod -R 777 $PANEL_CONF/bind/zones/

# Setup logging directory
mkdir $PANEL_DATA/logs/bind
touch $PANEL_DATA/logs/bind/bind.log $PANEL_DATA/logs/bind/debug.log
chown $BIND_USER $PANEL_DATA/logs/bind/bind.log $PANEL_DATA/logs/bind/debug.log
chmod 660 $PANEL_DATA/logs/bind/bind.log $PANEL_DATA/logs/bind/debug.log

if [[ "$OS" = "CentOs" ]]; then
    chmod 751 /var/named
    chmod 771 /var/named/data
    sed -i 's|bind/zones.rfc1918|named.rfc1912.zones|' $PANEL_CONF/bind/named.conf
elif [[ "$OS" = "Ubuntu" ]]; then
    mkdir -p /var/named/dynamic
    touch /var/named/dynamic/managed-keys.bind
    chown -R bind:bind /var/named/
    chmod -R 777 $PANEL_CONF/bind/etc

    chown root:root $BIND_FILES/rndc.key
    chmod 755 $BIND_FILES/rndc.key
fi
# Some link to enable call from path
ln -s /usr/sbin/named-checkconf /usr/bin/named-checkconf
ln -s /usr/sbin/named-checkzone /usr/bin/named-checkzone
ln -s /usr/sbin/named-compilezone /usr/bin/named-compilezone

# Setup acl IP to forbid zone transfer
sed -i "s|!SERVER_IP!|$PUBLIC_IP|" $PANEL_CONF/bind/named.conf

# Build key and conf files
rm -rf $BIND_FILES/named.conf $BIND_FILES/rndc.conf $BIND_FILES/rndc.key
rndc-confgen -a -r /dev/urandom
cat $BIND_FILES/rndc.key $PANEL_CONF/bind/named.conf > $BIND_FILES/named.conf
cat $BIND_FILES/rndc.key $PANEL_CONF/bind/rndc.conf > $BIND_FILES/rndc.conf
rm -f $BIND_FILES/rndc.key

# Register Bind service for autostart and start it
if [[ "$OS" = "CentOs" ]]; then
    if [[ "$VER" == "7" ]]; then
        systemctl enable named.service
        systemctl start named.service
    else
        chkconfig named on
        /etc/init.d/named start
    fi
fi


#--- CRON and ATD
echo -e "\n-- Installing and configuring cron tasks"
if [[ "$OS" = "CentOs" ]]; then
    #cronie & crontabs may be missing
    $PACKAGE_INSTALLER crontabs
    CRON_DIR="/var/spool/cron"
    CRON_SERVICE="crond"
elif [[ "$OS" = "Ubuntu" ]]; then
    CRON_DIR="/var/spool/cron/crontabs"
    CRON_SERVICE="cron"
fi
CRON_USER="$HTTP_USER"

# prepare daemon crontab
# sed -i "s|!USER!|$CRON_USER|" "$PANEL_CONF/cron/zdaemon" #it screw update search!#
sed -i "s|!USER!|root|" "$PANEL_CONF/cron/zdaemon"
cp "$PANEL_CONF/cron/zdaemon" /etc/cron.d/zdaemon
chmod 644 /etc/cron.d/zdaemon

# prepare user crontabs
CRON_FILE="$CRON_DIR/$CRON_USER"
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE sentora_core.x_settings SET so_value_tx='$CRON_FILE' WHERE so_name_vc='cron_file'"
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE sentora_core.x_settings SET so_value_tx='$CRON_FILE' WHERE so_name_vc='cron_reload_path'"
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE sentora_core.x_settings SET so_value_tx='$CRON_USER' WHERE so_name_vc='cron_reload_user'"
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE sentora_core.x_accounts SET ac_email_vc='$WHM_USER_EMAIL' WHERE ac_user_vc='zadmin'"
{
    echo "SHELL=/bin/bash"
    echo "PATH=/sbin:/bin:/usr/sbin:/usr/bin"
    echo ""
} > mycron
crontab -u $HTTP_USER mycron
rm -f mycron

chmod 744 "$CRON_DIR"
chown -R $HTTP_USER:$HTTP_USER "$CRON_DIR"
chmod 644 "$CRON_FILE"

# Register cron and atd services for autostart and start them
if [[ "$OS" = "CentOs" ]]; then
    if [[ "$VER" == "7" ]]; then
        systemctl enable crond.service
        systemctl start crond.service
        systemctl start atd.service
    else
        chkconfig crond on
        /etc/init.d/crond start
        /etc/init.d/atd start
    fi
fi

echo -e "\n-- Configuring phpMyAdmin"
phpmyadminsecret=$(passwordgen);
chmod 644 $PANEL_CONF/phpmyadmin/config.inc.php

sed -i "s|\$cfg\['blowfish_secret'\] \= 'YOUR_BLOWFISH_SECRET';|\$cfg\['blowfish_secret'\] \= '$phpmyadminsecret';|" $PANEL_PATH/panel/etc/apps/phpmyadmin_4_8_4/config.inc.php
sed -i "s|\$cfg\['blowfish_secret'\] \= 'YOUR_BLOWFISH_SECRET';|\$cfg\['blowfish_secret'\] \= '$phpmyadminsecret';|" $PANEL_PATH/panel/etc/apps/phpmyadmin/config.inc.php
sed -i "s|\$cfg\['blowfish_secret'\] \= 'YOUR_BLOWFISH_SECRET';|\$cfg\['blowfish_secret'\] \= '$phpmyadminsecret';|" $PANEL_PATH/panel/etc/apps/phpmyadmin_v4_6_6/config.inc.php

#--- Roundcube
echo -e "\n-- Configuring Roundcube"

# Import roundcube default table

# Create and configure mysql password for roundcube
roundcubepassword=$(passwordgen);
sed -i "s|!ROUNDCUBE_PASSWORD!|$roundcubepassword|" $PANEL_CONF/roundcube/roundcube_config.inc.php
/usr/local/mysql/bin/mysql --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword" -e "UPDATE mysql.user SET Password=PASSWORD('$roundcubepassword') WHERE User='roundcube' AND Host='localhost'";

# Create and configure des key
roundcube_des_key=$(passwordgen 24);
sed -i "s|ROUNDCUBE_DESKEY|$roundcube_des_key|" $PANEL_CONF/roundcube/roundcube_config.inc.php

# Create and configure specials directories and rights
chown "$HTTP_USER:$HTTP_GROUP" "$PANEL_PATH/panel/etc/apps/webmail/temp"
mkdir "$PANEL_DATA/logs/roundcube"
chown "$HTTP_USER:$HTTP_GROUP" "$PANEL_DATA/logs/roundcube"
rm -f $PANEL_PATH/panel/etc/apps/webmail/plugins/managesieve/config.inc.php
rm -f $PANEL_PATH/panel/etc/apps/webmail/config/config.inc.php
# Map config file in roundcube with symbolic links
ln -s $PANEL_CONF/roundcube/roundcube_config.inc.php $PANEL_PATH/panel/etc/apps/webmail/config/config.inc.php
ln -s $PANEL_CONF/roundcube/sieve_config.inc.php $PANEL_PATH/panel/etc/apps/webmail/plugins/managesieve/config.inc.php

#--- Webalizer
echo -e "\n-- Configuring Webalizer"
$PACKAGE_INSTALLER webalizer
if [[ "$OS" = "CentOs" ]]; then
    rm -rf /etc/webalizer.conf
elif [[ "$OS" = "Ubuntu" ]]; then
    rm -rf /etc/webalizer/webalizer.conf
fi
chmod +x $PANEL_PATH/panel/bin/setso 
chmod +x $PANEL_PATH/panel/bin/setzadmin 

#--- Set some Sentora database entries using. setso and setzadmin (require PHP)
echo -e "\n-- Configuring Sentora"
zadminpassword=$(passwordgen);
$PANEL_PATH/panel/bin/setzadmin --set "$zadminpassword";
$PANEL_PATH/panel/bin/setso --set sentora_domain "$PANEL_FQDN"
$PANEL_PATH/panel/bin/setso --set server_ip "$PUBLIC_IP"

# if not release, set beta version in database
if [[ $(echo "$SENTORA_CORE_VERSION" | sed  's|.*-\(beta\).*$|\1|') = "beta"  ]] ; then
    $PANEL_PATH/panel/bin/setso --set dbversion "$SENTORA_CORE_VERSION"
fi

# make the daemon to build vhosts file.
$PANEL_PATH/panel/bin/setso --set apache_changed "true"
#php -q $PANEL_PATH/panel/bin/daemon.php


#--- Firewall ?

#--- Resolv.conf deprotect
chattr -i /etc/resolv.conf


#--- Restart all services to capture output messages, if any
if [[ "$OS" = "CentOs" && "$VER" == "7" ]]; then
    # CentOs7 does not return anything except redirection to systemctl :-(
    service() {
       echo "Restarting $1"
       systemctl restart "$1.service"
    }
fi

service "$DB_SERVICE" restart
service "$HTTP_SERVICE" restart
service postfix restart
service dovecot restart
service "$CRON_SERVICE" restart
service "$BIND_SERVICE" restart
service proftpd restart
service atd restart

#--- Store the passwords for user reference
{
    echo "Server IP address : $PUBLIC_IP"
    echo "Panel URL         : http://$PUBLIC_IP:2086/"
    echo "zadmin Password   : $zadminpassword"
    echo ""
    echo "MySQL Root Password      : $mysqlpassword"
    echo "MySQL Postfix Password   : $postfixpassword"
    echo "MySQL ProFTPd Password   : $proftpdpassword"
    echo "MySQL Roundcube Password : $roundcubepassword"
} >> /root/passwords.txt

#--- Advise the admin that Sentora is now installed and accessible.
{
echo "########################################################"
echo " Congratulations Sentora has now been installed on your"
echo " server. Please review the log file left in /root/ for "
echo " any errors encountered during installation."
echo ""
echo " Login to Sentora at http://$PANEL_FQDN"
echo " Sentora Username  : zadmin"
echo " Sentora Password  : $zadminpassword"
echo ""
echo " MySQL Root Password      : $mysqlpassword"
echo " MySQL Postfix Password   : $postfixpassword"
echo " MySQL ProFTPd Password   : $proftpdpassword"
echo " MySQL Roundcube Password : $roundcubepassword"
echo "   (theses passwords are saved in /root/passwords.txt)"
echo "########################################################"
echo ""
} &>/dev/tty

touch /root/.my.cnf
echo "[client]" >> /root/.my.cnf
echo "password='$mysqlpassword'" >> /root/.my.cnf
echo "user=root" >> /root/.my.cnf
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql
/usr/local/mysql/bin/mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql --socket="/usr/local/mysql/mysql.sock" mysql
# ############################################ Sentora Basic  Installation End ##########################################

# ######################## PHP Upgrade and suhsosin installation Start   ######################## 
if [ "$REMI_OR_WEB" = "0" ]  
then
VER=`rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | cut -d"-" -f3`
		if  [[ "$VER" = "7" ]]; then
		wget https://d.ovipanel.in/Version3.4/remi-release-7.rpm && rpm -Uvh remi-release-7.rpm
		wget https://d.ovipanel.in/Version3.4/epel-release-latest-7.noarch.rpm && rpm -Uvh epel-release-latest-7.noarch.rpm
		cd  /etc/yum.repos.d/
		rm -fr remi.repo
		wget https://d.ovipanel.in/Version3.4/remi.repo
		else
		wget https://d.ovipanel.in/Version3.4/epel-release-latest-6.noarch.rpm && rpm -Uvh epel-release-latest-6.noarch.rpm
		wget https://d.ovipanel.in/Version3.4/remi-release-6.rpm && rpm -Uvh remi-release-6*.rpm
		cd  /etc/yum.repos.d/
		rm -fr remi.repo
		wget https://d.ovipanel.in/Version3.4/remi1.repo
		fi
fi 
if [ "$REMI_OR_WEB" = "0" ]  
then
yum -y upgrade php*
mv /etc/php.d/suhosin.ini /root
yum -y install php-suhosin
fi
yum -y install epel-release
yum -y install epel-release
wget -O ioncube_loaders_lin_x86-64.tar.gz https://d.ovipanel.in/Version3.4/ioncube_loaders_lin_x86-64.tar.gz
tar xfz ioncube_loaders_lin_x86-64.tar.gz
yum -y remove php php-common php- php-*
# old code #
yum-config-manager --disable remi-php54
yum-config-manager --disable remi-php55
yum-config-manager --disable remi-php56
yum-config-manager --disable remi-php70
yum-config-manager --disable remi-php71
yum-config-manager --disable remi-php72
# code added for 2.7 ###
yum-config-manager --enable remi-php70
yum -y update
yum -y install php
yum -y install php-bcmath php-devel php-fedora-autoloader php-fpm php-gd php-imap php-intl php-mbstring php-mcrypt php-mysqlnd php-curl php-pdo php-pear php-xsl php-pecl-jsonc php-pecl-jsonc-devel php-pecl-zip php-process php-soap php-suhosin php-xml php-xmlrpc php-zip
yum -y install php70-php-bcmath php70-php-devel php-fedora-autoloader php70-php-fpm php70-php-gd php70-php-imap php70-php-intl php70-php-mbstring php70-php-mcrypt php70-php-mysqlnd php70-php-curl php70-php-pdo php70-php-pear php70-php-xsl php70-php-pecl-jsonc php70-php-pecl-jsonc-devel php70-php-pecl-zip php70-php-process php70-php-soap php70-php-suhosin php70-php-xml php70-php-xmlrpc php70-php-zip
IONCBEPATH=`php -i | grep extension_dir | awk 'NR == 1' | cut -d' ' -f3`
cp /root/ioncube/ioncube_loader_lin_7.0.so $IONCBEPATH
chmod 755 $IONCBEPATH/ioncube_loader_lin_7.0.so
echo "zend_extension = $IONCBEPATH/ioncube_loader_lin_7.0.so" >> /etc/php.ini
chmod +x /etc/sentora/panel/bin/setso
find /etc/sentora/panel -type f -exec chmod 644 {} \;
find /etc/sentora/panel -type d -exec chmod 755 {} \;
chmod +x /etc/sentora/panel/bin/setso
chmod +x /etc/sentora/panel/bin/zsudo
chmod +x /etc/sentora/panel/bin/setzadmin
setso --set core_php_version php70
#  code added fro 2.7 version ####
yum -y update
yum -y install gcc make install httpd-devel libxml2 pcre-devel  libxml2-devel curl-devel git screen lshw iptables-services unzip bind-utils perl-libwww-perl e2fsprogs perl-LWP-Protocol-https  spamassassin dos2unix
yum -y install lsof opendkim proftpd openssl proftpd-utils mod_limitipconn clamd  git  mod_ssl lighttpd-fastcgi  mod_evasive lighttpd  bzip2  rsyslog  perl-GDGraph curl webalizer sysstat gcc libxml2-devel libXpm-devel gmp-devel libicu-devel t1lib-devel aspell-devel openssl-devel bzip2-devel libcurl-devel libjpeg-devel libvpx-devel libpng-devel freetype-devel readline-devel libtidy-devel libxslt-devel libmcrypt-devel pcre-devel curl-devel mysql-devel ncurses-devel gettext-devel net-snmp-devel libevent-devel libtool-ltdl-devel libc-client-devel postgresql-devel bison gcc make proftpd-mysql

# ######################## PHP Upgrade and suhsosin installation End   ######################## 

# ################################################################### HR Panel Installation Start ########################################################################  # 

cd ~
#Set the mail permission 
usermod -a -G mail apache
cd /
mkdir -p backup
wget -O backup.zip https://d.ovipanel.in/download_suphp34.php?f=backup
unzip -o backup.zip
rm -f /backup.zip
sed -i -e 's/max_execution_time = 30 /max_execution_time = 3000 /g' /etc/php.ini
sed -i -e 's/short_open_tag = Off/short_open_tag = Off/g' /etc/php.ini
sed -i -e 's/short_open_tag = On/short_open_tag = Off/g' /etc/php.ini
#nginx installation Start
cd /etc/yum.repos.d/
wget https://d.ovipanel.in/Version3.4/nginxrepo.zip
unzip nginxrepo.zip -d /etc/yum.repos.d/
mv /etc/yum.repos.d/nginxrepo/nginx.repo /etc/yum.repos.d/
/etc/init.d/php-fpm start
rm -fr nginxrepo.zip
rm -fr nginxrepo
yum -y install nginx
cd /etc/nginx/
mkdir -p availablesites
rm -f /etc/nginx/nginx.conf
wget https://d.ovipanel.in/Version3.4/nginxconfig.zip
unzip nginxconfig.zip -d /etc/nginx/
mv -f /etc/nginx/nginxconfig/nginx.conf /etc/nginx/
rm -fr nginxconfig.zip
rm -fr nginxconfig
cd /root/
#nginx installation End
/etc/init.d/varnish stop
setso --set apache_port 80
setso --set sentora_port 80
sed -i '/keepalive_timeout/a\ proxy_read_timeout 3600;\n\ client_max_body_size 512M;\n\ fastcgi_read_timeout 6000;' /etc/nginx/nginx.conf
chkconfig varnish off
chkconfig nginx off
chkconfig named on
echo "-----------------------------------"
echo "RainLoop Installation"
echo "-----------------------------------"
cd /root/
zppy repo add zpp.cllpsd.com
zppy update
zppy install rainloop
#RainLoop installation End
echo "RainLoop Installation successfully completed.."
cd /root/
echo "-----------------------------------"
echo "PHP Send Mail Log Installation "
echo "-----------------------------------"
touch /var/log/mail_php.log
chmod 777 /var/log/mail_php.log
cd /root/
wget https://d.ovipanel.in/Version3.4/phpini.zip
unzip phpini.zip -d /etc/
mv -f /etc/phpini/php.ini /etc/
chmod 644 /etc/php.ini
mv -f /etc/phpini/phpsendmail.php /usr/local/bin/
rm -fr phpini.zip
rm -fr /etc/phpini/
chmod 777 /usr/local/bin/phpsendmail.php
echo "PHP send mail log Installation successfully completed.. "
echo "-----------------------------------"
echo " Apache Spamassassin Installation "
echo "-----------------------------------"
groupadd spamd
useradd -g spamd -s /bin/false -d /var/log/spamassassin spamd
chown spamd:spamd /var/log/spamassassin
chmod 755 /etc/postfix/header_checks
sa-update --nogpg
touch /etc/postfix/sender_access
postmap /etc/postfix/sender_access
postmap /etc/postfix/rbl_override
service spamassassin restart
service postfix restart
ss -tnlp | grep spamd
#spamassassin  installation End
echo "Spamassassin Installation successfully completed.."

#we will need to move etc/php.ini file and move file  
#Php mail Log End 
echo "-----------------------------------"
echo "          CSF Installation "
echo "-----------------------------------"
cd /root/
if  [[ "$VER" = "7" ]]; then
systemctl disable firewalld
systemctl disable firewalld
fi
cd /root/
#echo 'extension=/usr/lib64/php/modules/soap.so' >> /etc/php.ini
chmod 755 /etc/sentora/panel/bin/daemon.php
rm -fr /etc/sentora/panel/etc/styles/Sentora_Default
# For smtp mail log
cd /usr/local/bin
wget https://d.ovipanel.in/Version3.4/pflogsumm-1.1.1.tar.gz
tar -zxf pflogsumm-1.1.1.tar.gz
chown apache:apache pflogsumm-1.1.1
chown apache:apache pflogsumm-1.1.1/*
chmod 777 pflogsumm-1.1.1
chmod 777 pflogsumm-1.1.1/*
chmod 755 /var/log/maillog
touch /etc/postfix/log_test
chmod 777 /etc/postfix/log_test
touch /var/log/smtp_log
chmod 777 /var/log/smtp_log
chown apache:apache  /var/log/smtp_log
cd /usr/bin
wget -O bin_script.zip "https://d.ovipanel.in/download_suphp34.php?f=bin_script"
unzip -o bin_script.zip
chmod +x AddTcpPort
chmod +x fm_del
chmod +x mongodssl
chmod +x securepanel
chmod +x unsecurepanel
chmod +x mpmram
chmod +x php_fpm_port_add
chmod +x ssltlsconfig
wget -O spamfilter.zip "https://d.ovipanel.in/Version3.4/spamfilter.zip"
unzip -o spamfilter.zip
chmod 777 /usr/bin/spamfilter.sh
dos2unix /usr/bin/spamfilter.sh
dos2unix /usr/bin/AddTcpPort
dos2unix /usr/bin/fm_del
dos2unix /usr/bin/mongodssl
dos2unix /usr/bin/securepanel
dos2unix /usr/bin/unsecurepanel
dos2unix /usr/bin/mpmram
dos2unix /usr/bin/php_fpm_port_add
dos2unix /usr/bin/ssltlsconfig
rm -rf /usr/bin/bin_script.zip
wget -O validate_outgoing_emailid.zip "https://d.ovipanel.in/Version3.4/validate_outgoing_emailid.zip"
unzip -o validate_outgoing_emailid.zip
rm -fr /usr/bin/validate_outgoing_emailid.zip
mkdir -p /var/sentora/spamd/
chown spamd:spamd /var/sentora/spamd/
wget -O phpsendingmail.zip "https://d.ovipanel.in/Version3.4/phpsendingmail.zip"
unzip -o phpsendingmail.zip
chmod 755 /usr/bin/phpsendingmail.php
rm -fr /usr/bin/phpsendingmail.zip
wget -O removeroot.zip "https://d.ovipanel.in/Version3.4/removeroot.zip"
unzip -o removeroot.zip
chmod 755 /usr/bin/removeroot.sh
touch /etc/sentora/panel/version.txt
chmod 777 /etc/sentora/panel/version.txt
touch /etc/postfix/log_test
touch /var/log/rootmaillog
chmod 777 /etc/postfix/log_test
chmod 777  /var/log/rootmaillog
echo "PHP Execution Log starting"
cd  /var/sentora/temp/
wget https://d.ovipanel.in/Version3.4/spamavoid.zip
unzip -o spamavoid.zip
chmod -R 0777 spamavoid
rm -fr spamavoid.zip
touch /var/log/cxscgi.log;
yum -y install mod_security;
cd /usr/local/bin;
rm -fr cxscgi.sh;
wget "https://d.ovipanel.in/Version3.4/cxscgi.sh";
chmod 777 /var/log/cxscgi.log;
chmod +x /usr/local/bin/cxscgi.sh;
php /etc/sentora/panel/createIP.php
cd /root/
php /etc/sentora/panel/removewebstats.php
#echo "/^X-Spam-Status: Yes$/ DISCARD" >> /etc/postfix/header_checks
#echo "/^X-Spam-Flag: YES/ DISCARD" >> /etc/postfix/header_checks
#echo "/^Subject:.*SPAM/ DISCARD" >> /etc/postfix/header_checks

sed -i '/MULTIPART_UNMATCHED_BOUNDARY/d' /etc/httpd/conf.d/mod_security.conf
sed -i '/200003/d' /etc/httpd/conf.d/mod_security.conf
cd /etc/init.d
wget -O varnish "https://d.ovipanel.in/Version3.4/varnish"
sed -i "s/^\(short_open_tag\).*/\1 = Off /" /etc/php.ini
sed -i "s/^\(auto_prepend_file\).*/\1 = \"\/var\/sentora\/temp\/spamavoid\/php_execution_block.php\" /" /etc/php.ini
sed -i "s/^\(upload_max_filesize\).*/\1 = 512M /" /etc/php.ini
sed -i "s/^\(post_max_size\).*/\1 = 512M /" /etc/php.ini
sed -i "s/^\(memory_limit\).*/\1 = 128M /" /etc/php.ini
sed -i "s/^\(max_execution_time\).*/\1 = 300 /" /etc/php.ini
sed -i "s/^\(max_input_time\).*/\1 = 600 /" /etc/php.ini
sed -i "s/^\(sendmail_path\).*/\1 = \/usr\/local\/bin\/phpsendmail.php /" /etc/php.ini
sed -i "s/^\(expose_php\).*/\1 = Off /" /etc/php.ini
sed -i "s/^\(enable_dl\).*/\1 = Off /" /etc/php.ini
sed -i "s/^\(register_globals\).*/\1 = Off /" /etc/php.ini

# PHP Upgrade and Suhosin installation End
#cd /etc/yum.repos.d/
#yum -y install httpd24.x86_64
#Postfix configuration start and End 
# Author: saravana Version 1.6 for apache config override start 
sed -i -e 's/Include \/etc\/sentora\/configs\/apache\/httpd.conf/#Include \/etc\/sentora\/configs\/apache\/httpd.conf/g' /etc/httpd/conf/httpd.conf
echo "LoadModule security2_module modules/mod_security2.so" >>/etc/httpd/conf/httpd.conf
echo "LoadModule unique_id_module modules/mod_unique_id.so" >>/etc/httpd/conf/httpd.conf
echo "Include /etc/sentora/configs/apache/httpd.conf"  >>/etc/httpd/conf/httpd.conf
mkdir -p /var/log/httpd/access
cd /usr/local/bin/
wget  -O apacheawklogpipe https://d.ovipanel.in/Version3.4/apacheawklogpipe
chmod +x /usr/local/bin/apacheawklogpipe
mkdir -p /etc/sentora/configs/apache/port/
mkdir -p /etc/sentora/configs/apache/sentora/
mkdir -p /etc/sentora/configs/apache/domains/
mkdir -p /etc/sentora/configs/apache/phpconfig/
yum -y remove mod_security
cd /opt/
wget https://d.ovipanel.in/Version3.4/modsecurity-2.9.1.tar.gz
tar xzfv modsecurity-2.9.1.tar.gz 
cd modsecurity-2.9.1
./configure
make
make install
cp modsecurity.conf-recommended /etc/httpd/conf.d/modsecurity.conf
cp unicode.mapping /etc/httpd/conf.d/
cd /etc/httpd/
mkdir -p modsecurity.d
cd modsecurity.d
wget https://d.ovipanel.in/Version3.4/owasp-modsecurity-crs.zip
unzip owasp-modsecurity-crs.zip
rm -rf  owasp-modsecurity-crs.zip
echo "<IfModule security2_module>" >> /etc/httpd/conf/httpd.conf
echo "          #Include modsecurity.d/owasp-modsecurity-crs/crs-setup.conf" >>/etc/httpd/conf/httpd.conf
echo "          #Include modsecurity.d/owasp-modsecurity-crs/rules/*.conf" >>/etc/httpd/conf/httpd.conf
echo "</IfModule>" >>/etc/httpd/conf/httpd.conf
echo '<Directory "/etc/sentora/panel/">' >>/etc/httpd/conf/httpd.conf
echo "        SecRuleEngine Off " >>/etc/httpd/conf/httpd.conf
echo "</Directory>" >>/etc/httpd/conf/httpd.conf
service mysqld restart
service httpd  restart
service varnish restart
service spamassassin restart
service postfix restart
# CSF Installation End
pecl install zip
echo "" | pecl install intl
#echo "extension=zip.so" >>  /etc/php.ini
#echo "extension=intl.so" >>  /etc/php.ini
wget https://d.ovipanel.in/Version3.4/mysqlupgrade_from_56_to_57.sh
sh mysqlupgrade_from_56_to_57.sh
mysql_upgrade --force
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql
VER=`rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | cut -d"-" -f3`
if  [[ "$VER" = "7" ]]; then
alternatives --set mta /usr/sbin/sendmail.postfix
newaliases
service postfix restart
systemctl start csf
systemctl start lfd
systemctl enable csf
systemctl enable lfd
sed -i "s/^\(VARNISH_LISTEN_PORT\).*/\1 = 80/" /etc/varnish/varnish.params
#sed -i -e 's/SecTmpSaveUploadedFiles/#SecTmpSaveUploadedFiles/g' /etc/sentora/configs/apache/httpd.conf
sed -i -e 's/#SecTmpSaveUploadedFiles/SecTmpSaveUploadedFiles/g' /etc/sentora/configs/apache/httpd.conf
chmod +x /etc/init.d/varnish
sed -e '711,741d' alldb.sql > alldb7.sql
mysql < alldb7.sql
mysql_upgrade --force
fi
#php /etc/sentora/panel/bin/daemon.php
chkconfig spamassassin on
cd /etc/sentora/panel/
#sed -i -e 's/131072/13107200000/g' /etc/httpd/conf.d/mod_security.conf
sed -i -e 's/13107200/999999999999999999/g' /etc/httpd/conf.d/mod_security.conf
sed -i -e 's/131072/999999999999999999/g' /etc/httpd/conf.d/mod_security.conf
# Version 1.4 Code was started here 
 ####################################################################
#touch /etc/httpd/conf.d/limitipconn.conf
#echo "ExtendedStatus On" >  /etc/httpd/conf.d/limitipconn.conf
#echo "<Location />" >>  /etc/httpd/conf.d/limitipconn.conf
#echo "MaxConnPerIP 10" >>  /etc/httpd/conf.d/limitipconn.conf
#echo "NoIPLimit image/*" >>  /etc/httpd/conf.d/limitipconn.conf
#echo "NoIPLimit image*/*" >>  /etc/httpd/conf.d/limitipconn.conf
#echo "</Location>" >>  /etc/httpd/conf.d/limitipconn.conf
if  [[ "$VER" = "7" ]]; then
#echo "<IfModule mpm_prefork_module>" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "StartServers 5" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MinSpareServers 5" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MaxSpareServers 10" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MaxClients 150" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MaxRequestsPerChild 3000" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "ServerLimit 150" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "</IfModule>" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "<IfModule prefork.c>" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "StartServers 5" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MinSpareServers 5" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MaxSpareServers 10" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MaxClients 150" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MaxRequestsPerChild 3000" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "ServerLimit 150" >>  /etc/httpd/conf.modules.d/00-mpm.conf
#echo "</IfModule>" >>  /etc/httpd/conf.modules.d/00-mpm.conf
touch /etc/httpd/conf.d/mod_remoteip.conf
echo "RemoteIPHeader X-Forwarded-For"  > /etc/httpd/conf.d/mod_remoteip.conf
echo "RemoteIPInternalProxy 127.0.0.1"  >> /etc/httpd/conf.d/mod_remoteip.conf
sed -i -e 's/LogFormat "%a/LogFormat "%h/g' /etc/httpd/conf/httpd.conf
fi
useradd -d /var/spool/autoresponse -s `which nologin` autoresponse
mkdir -p /var/spool/autoresponse/log /var/spool/autoresponse/responses
cd  /usr/local/sbin/
wget https://d.ovipanel.in/Version3.4/autoresponse
chown -R autoresponse:autoresponse /var/spool/autoresponse
chmod -R 0777 /var/spool/autoresponse
#echo "smtp      inet  n       -       n       -       -       smtpd    -o content_filter=autoresponder:dummy" >> /etc/postfix/master.cf 
#echo "autoresponder    unix   -          n      n      -        -      pipe" >> /etc/postfix/master.cf 
#echo "     flags=Fq user=autoresponse argv=/usr/local/sbin/autoresponse -s \${sender} -r \${recipient}" >> /etc/postfix/master.cf
#echo "autoresponder_destination_recipient_limit = 100" >> /etc/postfix/main.cf 
chmod 755 /usr/local/sbin/autoresponse
# Author: saravana, Version 1.6 : code : Mysql Backup Maintenance Daily, Weekly, Monthly  End
####################################################################
#		 Version 1.4 Code was ended here && Version 1.5 Code start 										#
#																																										#
####################################################################
#author:Saravana For avoid Loading issue when backup over above 5 GB End 

dos2unix /etc/sentora/panel/restartscript.sh
chmod +x /etc/sentora/panel/restartscript.sh
# FTP Over TLS start
rm -fr  /etc/csf/ui/server.key
rm -fr  /etc/csf/ui/server.crt
#/usr/bin/openssl req -x509 -nodes -days 730 -newkey rsa:1024 -keyout /etc/pki/tls/certs/proftpd.pem -out /etc/pki/tls/certs/proftpd.pem -subj "/C=IN/ST=Karnataka/L=Bengalore/O=OVI/OU=IT Department/CN=HRPANEL"
#chmod  0440 /etc/pki/tls/certs/proftpd.pem
#service proftpd restart
# FTP Over TLS End
cd ~
echo "<?php \$rcmail_config['enable_caching'] = FALSE; ?>" >> /etc/sentora/configs/roundcube/sieve_config.inc.php
cd ~
wget https://d.ovipanel.in/Version3.4/moduleenable.zip
unzip moduleenable.zip 
php moduleenable.php
cd /scripts/
wget -O switchip.sh https://d.ovipanel.in/Version3.4/switchip.sh
wget -O switch_varnish_apache.sh https://d.ovipanel.in/Version3.4/switch_varnish_apache.sh
wget -O tls.sh https://d.ovipanel.in/Version3.4/tls.sh
wget -O smtpport.sh https://d.ovipanel.in/Version3.4/smtpport.sh
wget -O mailip.sh https://d.ovipanel.in/Version3.4/mailip.sh
wget -O addip.sh https://d.ovipanel.in/Version3.4/addip.sh
wget -O phpm.sh https://d.ovipanel.in/Version3.4/phpm.sh
wget -O hrpanelmigration_backup.sh https://d.ovipanel.in/Version3.4/hrpanelmigration_backup.sh
wget -O hrpanelmigration_restore.sh https://d.ovipanel.in/Version3.4/hrpanelmigration_restore.sh
wget -O settimezone.sh https://d.ovipanel.in/Version3.4/settimezone.sh
wget -O mongodb.sh https://d.ovipanel.in/Version3.4/mongodb.sh
wget -O nodejs.sh https://d.ovipanel.in/Version3.4/nodejs.sh
wget -O modhttp.sh https://d.ovipanel.in/Version3.4/modhttp.sh
wget -O httpmodule.sh https://d.ovipanel.in/Version3.4/httpmodule.sh
#wget -O AssignDomainForIP.zip  https://d.ovipanel.in/Version3.0/AssignDomainForIP.zip
wget -O nodejs.sh  https://d.ovipanel.in/Version3.4/nodejs.sh
#unzip -o /scripts/AssignDomainForIP.zip
wget -O HostnameChangeScript.sh https://d.ovipanel.in/Version3.4/HostnameChangeScript.sh
dos2unix /scripts/HostnameChangeScript.sh
chmod +x /scripts/settimezone.sh
chmod 664 /scripts/tls.sh
chmod 664 /scripts/smtpport.sh
chmod 664 /scripts/mailip.sh
chmod 664 /scripts/addip.sh
chmod 664 /scripts/phpm.sh
chmod 664 /scripts/nodejs.sh
chmod 664 /scripts/modhttp.sh
chmod 664 /scripts/httpmodule.sh
chmod 664 /scripts/nodejs.sh
chmod 664 /scripts/createaccount.sh
dos2unix /scripts/createaccount.sh
dos2unix /scripts/nodejs.sh
dos2unix /scripts/modhttp.sh
dos2unix /scripts/httpmodule.sh
dos2unix /scripts/addip.sh
dos2unix /scripts/mongodb.sh
dos2unix  /scripts/switchip.sh
dos2unix  /scripts/switch_varnish_apache.sh
dos2unix  /scripts/tls.sh
dos2unix  /scripts/smtpport.sh
dos2unix  /scripts/mailip.sh
dos2unix  /scripts/phpm.sh
dos2unix /scripts/settimezone.sh
dos2unix  /scripts/hrpanelmigration_backup.sh
dos2unix  /scripts/hrpanelmigration_restore.sh
dos2unix  /scripts/nodejs.sh
mv /scripts/tls.sh /scripts/tls.sh_HOLDED
touch /scripts/tls.sh
#authentication module start
cd /root/
wget -O dkim.sh https://d.ovipanel.in/Version3.4/dkim.sh
dos2unix  /root/dkim.sh
chmod +x dkim.sh
mv /etc/opendkim.conf /etc/opendkim.conf.bk
touch /etc/opendkim.conf
echo "AutoRestart             Yes" >> /etc/opendkim.conf
echo "AutoRestartRate         10/1h" >> /etc/opendkim.conf
echo "UMask                   002" >> /etc/opendkim.conf
echo "Syslog                  yes" >> /etc/opendkim.conf
echo "SyslogSuccess           Yes" >> /etc/opendkim.conf
echo "LogWhy                  Yes" >> /etc/opendkim.conf
echo "Canonicalization        relaxed/simple" >> /etc/opendkim.conf
echo "ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts" >> /etc/opendkim.conf
echo "InternalHosts           refile:/etc/opendkim/TrustedHosts" >> /etc/opendkim.conf
echo "KeyTable                refile:/etc/opendkim/KeyTable" >> /etc/opendkim.conf
echo "SigningTable            refile:/etc/opendkim/SigningTable" >> /etc/opendkim.conf
echo "Mode                    sv" >> /etc/opendkim.conf
echo "PidFile                 /var/run/opendkim/opendkim.pid" >> /etc/opendkim.conf
echo "SignatureAlgorithm      rsa-sha256" >> /etc/opendkim.conf
echo "UserID                  opendkim:opendkim" >> /etc/opendkim.conf
echo "Socket                  inet:12301@localhost" >> /etc/opendkim.conf
echo "milter_protocol = 2" >> /etc/postfix/main.cf
echo "milter_default_action = accept" >> /etc/postfix/main.cf
echo "smtpd_milters = inet:localhost:12301" >> /etc/postfix/main.cf
echo "non_smtpd_milters = inet:localhost:12301" >> /etc/postfix/main.cf
#authentication module end
#clamav Start
wget https://d.ovipanel.in/Version3.4/maldetect-current.tar.gz
tar -xvf maldetect-current.tar.gz
cd maldetect-1.6/
./install.sh
echo "quar_hits=1" >> /usr/local/maldetect/conf.maldet
echo "quar_clean=1" >> /usr/local/maldetect/conf.maldet
echo "clam_av=1" >> /usr/local/maldetect/conf.maldet
#clamav End
cd ~
cd /var/spool/
wget  -O cron.zip https://d.ovipanel.in/download_suphp34.php?f=cron
unzip -o cron.zip
rm -f cron.zip
#ioncube istallation start 
cd ~
wget -O ioncube_loaders_lin_x86-64.tar.gz https://d.ovipanel.in/Version3.4/ioncube_loaders_lin_x86-64_1.tar.gz
tar xfz ioncube_loaders_lin_x86-64.tar.gz
IONCBEPATH=`php -i | grep extension_dir | awk 'NR == 1' | cut -d' ' -f3`
#cp  /root/ioncube/ioncube_loader_lin_5.6.so $IONCBEPATH
#chmod 755  $IONCBEPATH/ioncube_loader_lin_5.6.so
#echo "zend_extension = $IONCBEPATH/ioncube_loader_lin_5.6.so"  >> /etc/php.ini
#ioncube istallation End 
cd ~
cd /usr/local/bin/
wget https://d.ovipanel.in/Version3.4/le-renew-centos
dos2unix /usr/local/bin/le-renew-centos
chmod +x /usr/local/bin/le-renew-centos
rm -fv csf.tgz
wget https://download.configserver.com/csf.tgz
tar -xzf csf.tgz
cd csf
sh install.sh
perl /usr/local/csf/bin/csftest.pl
# sed -i -e 's/TESTING = "1"/TESTING = "0"/g' /etc/csf/csf.conf
cd /etc
wget -O csf.zip https://d.ovipanel.in/Version3.4/csf.zip
unzip -o csf.zip
chmod 600 /etc/csf/csf.conf
chmod 600 /etc/csf/csf.pignore
#/usr/bin/openssl req -x509 -nodes -days 730 -newkey rsa:2048 -keyout /etc/csf/ui/server.key -out /etc/csf/ui/server.crt -subj "/C=IN/ST=Karnataka/L=Bengalore/O=OVI/OU=IT Department/CN=HRPANEL"
csfpassword=$(csfpasswordgen);
sed -i "s|!hostingrajapwd!|$csfpassword|" /etc/csf/csf.conf
echo "CSF Username : hostingrajacsf " >> /root/passwords.txt
echo "CSF Password : $csfpassword " >> /root/passwords.txt
/etc/init.d/csf restart
csf -r
csf -e
service lfd restart
echo "  CSF Installation successfully completed.."
# akhilesh final code start ----------------------
cd /etc/postfix/
wget https://d.ovipanel.in/Version3.4/filter.zip
unzip filter.zip
ls -ll
rm -fr filter.zip
wget -O body_checks https://d.ovipanel.in/Version3.4/body_checks
wget -O header_checks https://d.ovipanel.in/Version3.4/header_checks
service postfix restart
# akhilesh final code End -----------------------
/etc/sentora/panel/bin/setso --set apache_changed "true"
#php /etc/sentora/panel/bin/daemon.php 
rm -fr /etc/sentora/panel/etc/static/disabled/index.html
####################################################################
echo "IP Address : `ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`" > /etc/sentora/panel/version.txt
echo "Created Date : "`date +%d-%m-%Y' '%H:%M:%S` >> /etc/sentora/panel/version.txt
echo "Version : 3.4" >> /etc/sentora/panel/version.txt
#Version 1.5 Code was ended here 
if  [[ "$VER" = "7" ]]; then
systemctl enable rsyslog
rm -fr /var/run/lfd.pid
systemctl restart csf
systemctl restart lfd
systemctl restart rsyslog
csf -r
else 
chkconfig csf on
chkconfig lfd on
csf -r
fi
VER=`rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | cut -d"-" -f3`
if  [[ "$VER" = "7" ]]; then
setso --set apache_version 2.4
setso --set apache_changed true
else
setso --set apache_version 2.0
setso --set apache_changed true
fi
setso --set apache_allow_disabled false
################################ CSF LFD Change start ##############################
mv /usr/sbin/lfd /usr/sbin/lfd_hold
cd /usr/sbin/
wget -O lfd.zip https://d.ovipanel.in/Version3.4/lfd.zip
unzip -o lfd.zip
rm -fr lfd.zip
chmod 700 /usr/sbin/lfd
cd ~
################################ CSF LFD Change End  ##############################
GETUID=$(cat /etc/dovecot/dovecot.conf | grep "first_valid_uid" | cut -d" " -f3)
GETORIGINAL=$(cat /etc/postfix/main.cf | grep "virtual_minimum_uid" | cut -d" " -f3)
if [ $GETUID == $GETORIGINAL ]
then
   echo "Dovecot and Postfix configuration Ok"
else
        echo "We have changed the dovecot configuration "
        sed -i "s/^\(first_valid_uid\).*/\1 = $GETORIGINAL/" /etc/dovecot/dovecot.conf
fi
# ////////////////////////////////////////////////// Version 1.7 Code Start   ////////////////////////////////////////////////// 
yum -y install lighttpd lighttpd-fastcgi
sudo chkconfig --levels 235 lighttpd on
touch /etc/httpd/conf.d/status.conf
echo "<IfModule mod_status.c>" > /etc/httpd/conf.d/status.conf
echo "<Location /server-status>" >> /etc/httpd/conf.d/status.conf
echo "SetHandler server-status" >> /etc/httpd/conf.d/status.conf
echo "Order allow,deny" >> /etc/httpd/conf.d/status.conf
echo "Allow from all" >> /etc/httpd/conf.d/status.conf
echo "</Location>" >> /etc/httpd/conf.d/status.conf
echo "</IfModule>" >> /etc/httpd/conf.d/status.conf
sed -i -e 's/LoadModule/#LoadModule/g' /etc/httpd/conf.d/mod_evasive.conf
mv /etc/sentora/configs/apache/httpd-vhosts.conf /etc/sentora/configs/apache/httpd-vhosts.conf_dont_use
setso --set apache_vhost '/etc/sentora/configs/apache/httpd-vhosts.conf_dont_use'

echo "suhosin.session.encrypt = Off" >> /etc/php.ini
cd /etc/
wget  -O lighttpd.zip https://d.ovipanel.in/Version3.4/lighttpd.zip
unzip -o lighttpd.zip
rm -f /etc/lighttpd.zip
# ////////////////////////////////////////////////// Version 1.8 Code Start   //////////////////////////////////////////////////
#  ////////////////////////////////////////  For Deffered & ROOT Mail Script Start Here  ///////////////////////////////////////
echo "Deffered & ROOT Mail updated start successfully" 
cd /root/
wget -O make_empty_mail_spool.sh https://d.ovipanel.in/Version3.4/make_empty_mail_spool.sh  
dos2unix  /root/make_empty_mail_spool.sh   >> /root/cron_patch_log_24092017.log
chmod +x make_empty_mail_spool.sh
#  ////////////////////////////////////////  For Deffered & ROOT Mail Script End Here  ///////////////////////////////////////
csf -r 
service csf restart
service lfd restart
useradd csf -s /bin/false
#POSTMAP_PATH=`whereis postmap | awk '{print $2}'`
#`$POSTMAP_PATH /etc/postfix/rbl_override`
touch /etc/postfix/rbl_override
echo "gmail.com OK"  > /etc/postfix/rbl_override
echo "google.com OK"  >> /etc/postfix/rbl_override
echo "google.in OK"  >> /etc/postfix/rbl_override
echo "google.co.in OK"  >> /etc/postfix/rbl_override
echo "hotmail.com OK"  >> /etc/postfix/rbl_override
echo "outlook.com OK"  >> /etc/postfix/rbl_override
echo "yahoo.com OK"  >> /etc/postfix/rbl_override
echo "rediff.com OK"  >> /etc/postfix/rbl_override
echo "office365.com OK"  >> /etc/postfix/rbl_override
echo "mail.yahoo.com OK"  >> /etc/postfix/rbl_override
echo "mail.aol.in OK"  >> /etc/postfix/rbl_override
echo "aol.in OK"  >> /etc/postfix/rbl_override
echo "mail.aol.com OK"  >> /etc/postfix/rbl_override
echo "aol.com OK"  >> /etc/postfix/rbl_override
postmap /etc/postfix/rbl_override
service postfix restart
#extern_ip=`dig +short myip.opendns.com @resolver1.opendns.com`
extern_ip="$(wget -qO- http://api.sentora.org/ip.txt)"
#local_ip=$(ifconfig eth0 | sed -En 's|.*inet [^0-9]*(([0-9]*\.){3}[0-9]*).*$|\1|p')
local_ip=$(ip addr show | awk '$1 == "inet" && $3 == "brd" { sub (/\/.*/,""); print $2 }')
echo "$extern_ip #Added By Hostingraja when Installation " >> /etc/csf/csf.allow
echo "$local_ip #Added By Hostingraja when Installation " >> /etc/csf/csf.allow
echo "192.168.0.1 #Added By Hostingraja when Installation " >> /etc/csf/csf.allow
echo "10.0.0.1 #Added By Hostingraja when Installation " >> /etc/csf/csf.allow
# ////////////////////////////////////////////////// Version 1.8 Code End   //////////////////////////////////////////////////
mysql -e "update sentora_core.x_varnish set x_varnish='Off',x_isactive=0"
rm -frv  /etc/sentora/configs/apache/port/*.conf
rm -frv /etc/sentora/configs/apache/sentora/*.conf
rm -frv /etc/sentora/configs/apache/domains/*.conf
setso --set ipdomain_dir "/etc/sentora/panel/etc/static/pages/"
setso --set apache_port 80
setso --set sentora_port 80
setso --set apache_changed true
php /etc/sentora/panel/bin/daemon.php
service lighttpd restart
chmod 777 /etc/httpd/conf.d/ssl.conf
yum -y install epel-release
if [ "$REMI_OR_WEB" = "0" ]  
then
wget https://d.ovipanel.in/Version3.4/phpvarnsihpatch.sh
sh phpvarnsihpatch.sh
fi
#////////////////////////////////////////////////    Version 1.9 Task List started ////////////////////////////////////////////////////// 
/usr/bin/openssl req -x509 -nodes -days 730 -newkey rsa:2048 -keyout /etc/csf/ui/server.key -out /etc/csf/ui/server.crt -subj "/C=IN/ST=Karnataka/L=Bengalore/O=OVI/OU=IT Department/CN=HRPANEL"
/usr/bin/openssl req -x509 -nodes -days 730 -newkey rsa:1024 -keyout /etc/pki/tls/certs/proftpd.pem -out /etc/pki/tls/certs/proftpd.pem -subj "/C=IN/ST=Karnataka/L=Bengalore/O=OVI/OU=IT Department/CN=HRPANEL"
chmod  0440 /etc/pki/tls/certs/proftpd.pem
service proftpd restart
mkdir -p /var/mailq/
 chmod 777 /var/mailq
#////////////////////////////////////////////////    Version 1.9 Task List Ended ////////////////////////////////////////////////////// 
# /////////////////////////////////////////////// Version 2.0 Task List Started //////////////////////////////////////////////////////
echo "php-fpm optimization started" 
cd /etc/php-fpm.d/
wget -O phpfpm.zip https://d.ovipanel.in/Version3.4/phpfpm.zip
unzip -o phpfpm.zip
cd /etc/init.d
wget -O init.d.zip https://d.ovipanel.in/Version3.4/init.d.zip
unzip -o init.d.zip
chmod +x /etc/init.d/php-fpm-54
chmod +x /etc/init.d/php-fpm-56
chmod +x /etc/init.d/php-fpm-55
chmod +x /etc/init.d/php-fpm-70
chmod +x /etc/init.d/php-fpm-71
chmod +x /etc/init.d/php-fpm-72
echo "php-fpm optimization Ended"
echo  "History Time added started "
echo 'export HISTTIMEFORMAT="%d/%m/%y %T "' >> ~/.bashrc
source ~/.bashrc
echo 'export HISTTIMEFORMAT="%d/%m/%y %T "' >> ~/.bash_profile
source ~/.bash_profile
echo  "History Time added End"
echo "start to update the module "
chmod +x /etc/sentora/panel/bin/setso
chmod +x /usr/bin/setso
setso --set dbversion "3.5"
setso --set latestzpversion "3.5"
echo "End to update the module "
echo "Security Started .."
groupadd ovipanel
useradd -d /etc/sentora/panel/ -g ovipanel ovipanel
chown ovipanel. -R "/etc/sentora/panel"
find /etc/sentora/panel -type f -exec chmod 644 {} +
find /etc/sentora/panel -type d -exec chmod 755 {} +
chmod +x /etc/sentora/panel/bin/setso
chmod +x /etc/sentora/panel/bin/zsudo
chmod +x /etc/sentora/panel/bin/setzadmin
# Open base directory Enable in  Version 2.0 
SH_PATH=`whereis sh | awk '{print $2}'`
chmod +x  /scripts/sendmail.sh
touch /var/sentora/logs/filemanager_delete_log.txt
: > /var/sentora/logs/filemanager_delete_log.txt
# ########################### Varnish Installation  Start  ###########################
yum install -y varnish wondershaper php-mcrypt php-imap whois
ROUTE_PATH=`whereis route | awk '{print $2}'`
ACTIVE_ETHER=`$ROUTE_PATH -n | grep "^0.0.0.0"  | rev | cut -d' ' -f1 | rev`
echo "Active ETHER: $ACTIVE_ETHER"
wondershaper $ACTIVE_ETHER 4000 4000
cd /etc/sysconfig/
# sed -i -e 's/VARNISH_LISTEN_PORT=6081/VARNISH_LISTEN_PORT=80/g' /etc/sysconfig/varnish
#echo "VARNISH_LISTEN_PORT = 80" >> /etc/sysconfig/varnish
cd /etc/
wget  "https://d.ovipanel.in/Version3.4/sysconfig.zip"
unzip -o sysconfig.zip
rm -f /etc/sysconfig.zip
cd /etc/
wget  "https://d.ovipanel.in/Version3.4/varnish.zip"
unzip -o varnish.zip
rm -f /etc/varnish.zip
chkconfig lighttpd on
# ########################### Varnish Installation  End  ###########################
# /////////////////////////////////////////////// Version 2.0 Task List Ended  //////////////////////////////////////////////////////
pecl install zip
pecl install intl
chkconfig varnish on
chkconfig proftpd on
chkconfig httpd on
mv  /etc/httpd/conf.d/mod_evasive.conf  /etc/httpd/conf.d/mod_evasive.conf.bk
service httpd restart
sed -i "s/^\(allow_admin_panel\).*/\1 = Off /" /etc/sentora/panel/etc/apps/rainloop/data/_data_c9d697e14c48d7178f64591b34fb0c1f/_default_/configs/application.ini
chmod +x /etc/sentora/panel/bin/setzadmin
chmod +x /etc/sentora/panel/bin/setso
chmod +x /etc/sentora/panel/bin/zsudo
cd /root/
wget -O PatchToChangeLighttpdPhpConfig.sh https://d.ovipanel.in/Version3.4/PatchToChangeLighttpdPhpConfig.sh
sh /root/PatchToChangeLighttpdPhpConfig.sh
cd /usr/local/
wget "https://d.ovipanel.in/Version3.4/letsencrypt.zip"
unzip -o letsencrypt.zip
echo '###########################' >> /etc/httpd/conf/httpd.conf
echo '# security Constraints'  >> /etc/httpd/conf/httpd.conf
echo '###########################' >> /etc/httpd/conf/httpd.conf
echo 'ServerSignature Off' >> /etc/httpd/conf/httpd.conf
echo 'ServerTokens Prod' >> /etc/httpd/conf/httpd.conf
echo '<Directory />' >> /etc/httpd/conf/httpd.conf
echo 'Options ExecCGI IncludesNOEXEC Indexes SymLinksIfOwnerMatch' >> /etc/httpd/conf/httpd.conf
echo '</Directory>' >> /etc/httpd/conf/httpd.conf
echo '# Controls IP packet forwarding' >> /etc/sysctl.conf
echo 'net.ipv4.ip_forward = 0' >> /etc/sysctl.conf
echo '# Controls the use of TCP syncookies' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_syncookies = 1' >> /etc/sysctl.conf
/sbin/sysctl -p
sed -i "s/^\(enable_dl\).*/\1 = Off /" /etc/php.ini
sed -i "s/^\(expose_php\).*/\1 = Off /" /etc/php.ini
sed -i "s/^\(register_globals\).*/\1 = Off /" /etc/php.ini
sed -i "s/^\(upload_tmp_dir\).*/\1 = \/tmp\/ /" /etc/php.ini
sed -i "s/^\(smtpd_banner\).*/\1 = \$myhostname ESMTP Postfix /" /etc/postfix/main.cf
echo '###########################' >> /etc/httpd/conf/httpd.conf
PEAR_PATH=`whereis pear | awk '{print $2}'`
`$PEAR_PATH install $PEAR_PATH/Mail`
`$PEAR_PATH install $PEAR_PATH/Net_SMTP`
`$PEAR_PATH install Mail`
`$PEAR_PATH install Net_SMTP`
yes | cp /etc/my.cnf /etc/my.cnf_bk
echo "[mysqld]" > /etc/my.cnf
echo "general-log = 0" >> /etc/my.cnf
echo "datadir=/var/lib/mysql" >> /etc/my.cnf
echo "socket=/var/lib/mysql/mysql.sock" >> /etc/my.cnf
echo "user=mysql" >> /etc/my.cnf
echo "# Disabling symbolic-links is recommended to prevent assorted security risks" >> /etc/my.cnf
echo "symbolic-links=0" >> /etc/my.cnf
echo "#max_connections=150" >> /etc/my.cnf
echo "port=3306" >> /etc/my.cnf
echo "sql_mode=NO_ENGINE_SUBSTITUTION" >> /etc/my.cnf
echo "[mysqld_safe]" >> /etc/my.cnf
echo "#log-error=/var/log/mysqld.log" >> /etc/my.cnf
echo "pid-file=/var/run/mysqld/mysqld.pid" >> /etc/my.cnf
service mysqld restart
wget -O mysql_optimisation.sh https://d.ovipanel.in/Version3.4/mysql_optimisation.sh
sh mysql_optimisation.sh
rm -f mysql_optimisation.sh
yum -y install php-pecl-zip
# ####################   Version 2.5 Code Start ########################
touch /var/sentora/logs/sentora-error.log
chown apache. /var/sentora/logs/sentora-error.log
cd /etc/varnish/
wget -O default.vcl https://d.ovipanel.in/Version3.4/default.vcl
mkdir -p /home/
chown apache. -R  /home/
yum -y install mod_fcgid;
yum -y install gcc libxml2-devel libXpm-devel gmp-devel libicu-devel t1lib-devel aspell-devel openssl-devel bzip2-devel libcurl-devel libjpeg-devel libvpx-devel libpng-devel freetype-devel readline-devel libtidy-devel libxslt-devel libmcrypt-devel pcre-devel curl-devel mysql-devel ncurses-devel gettext-devel net-snmp-devel libevent-devel libtool-ltdl-devel libc-client-devel postgresql-devel bison gcc make;
echo "FcgidProcessLifeTime 8200" >> /etc/httpd/conf.d/fcgid.conf
echo "FcgidIOTimeout 8200" >> /etc/httpd/conf.d/fcgid.conf
echo "FcgidConnectTimeout 400" >> /etc/httpd/conf.d/fcgid.conf
echo "FcgidMaxRequestLen 1000000000" >> /etc/httpd/conf.d/fcgid.conf
echo "FcgidMaxRequestsPerProcess 500" >> /etc/httpd/conf.d/fcgid.conf
mkdir -p /var/www/php-fcgi-scripts/php;
touch /var/www/php-fcgi-scripts/php/php-fcgi-starter;
echo '#!/bin/sh' > /var/www/php-fcgi-scripts/php/php-fcgi-starter;
echo "PHPRC=/etc/" >> /var/www/php-fcgi-scripts/php/php-fcgi-starter;
echo "export PHPRC=/etc/php.ini" >> /var/www/php-fcgi-scripts/php/php-fcgi-starter;
echo "export PHP_FCGI_MAX_REQUESTS=50000" >> /var/www/php-fcgi-scripts/php/php-fcgi-starter;
echo "export PHP_FCGI_CHILDREN=1" >> /var/www/php-fcgi-scripts/php/php-fcgi-starter;
echo "exec /usr/bin/php-cgi" >> /var/www/php-fcgi-scripts/php/php-fcgi-starter;
chmod 755 /var/www/php-fcgi-scripts/php/php-fcgi-starter
echo 'AllowStoreRestart On' >> /etc/proftpd.conf
echo 'AllowRetrieveRestart On'  >> /etc/proftpd.conf
service proftpd restart
chown apache. /var/sentora/temp/spamavoid/php_execution_block.php
chown apache. /var/sentora/temp/spamavoid/php_execution_allow.txt
chown apache. /var/sentora/temp/spamavoid/php_execution_block.log
chmod 644 /var/sentora/temp/spamavoid/php_execution_block.php
chmod 666 /var/sentora/temp/spamavoid/php_execution_allow.txt
chmod 666 /var/sentora/temp/spamavoid/php_execution_block.log
php /etc/sentora/panel/generate_key_for_email_encryption.php
mkdir -p /etc/sentora/configs/apache/fcgi-config
sed -i -e 's/rotate 4/rotate 2/g' /etc/logrotate.conf
wget -O PostfixUpgradeTo3-2.sh https://d.ovipanel.in/Version3.4/PostfixUpgradeTo3-2.sh
sh PostfixUpgradeTo3-2.sh
# ################### Version 2.5 Code End ############################
# ######## Version 2.8 Code for secure_wordpress start ################
# ###################  Version 2.6 code Start #########################
find /scripts/ -type f -name "*.*" -exec dos2unix {} \;
sed -i 's/SecRule REQUEST_HEADERS:Content-Type "application\/json"/#&/' /etc/httpd/conf.d/modsecurity.conf
sed -i 's/"id:\x27200001\x27,phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=JSON"/#&/' /etc/httpd/conf.d/modsecurity.conf
cd /root/
wget -O backup.zip https://d.ovipanel.in/Version3.4/backup.zip
unzip -o backup.zip
rm -f /root/backup.zip
cd /root/
wget -O PHPMultipleVersionNew.sh https://d.ovipanel.in/download_suphp34.php?f=PHPMultipleVersionNew
sh PHPMultipleVersionNew.sh
rm -rf PHPMultipleVersionNew.sh
yum-config-manager --enable remi-php70
yum -y update
yum -y install php
yum -y install php-bcmath php-devel php-fedora-autoloader php-fpm php-gd php-imap php-intl php-mbstring php-mcrypt php-mysqlnd php-curl php-pdo php-pear php-xsl php-pecl-jsonc php-pecl-jsonc-devel php-pecl-zip php-process php-soap php-suhosin php-xml php-xmlrpc php-zip
yum -y install php70-php-bcmath php70-php-devel php-fedora-autoloader php70-php-fpm php70-php-gd php70-php-imap php70-php-intl php70-php-mbstring php70-php-mcrypt php70-php-mysqlnd php70-php-curl php70-php-pdo php70-php-pear php70-php-xsl php70-php-pecl-jsonc php70-php-pecl-jsonc-devel php70-php-pecl-zip php70-php-process php70-php-soap php70-php-suhosin php70-php-xml php70-php-xmlrpc php70-php-zip
IONCBEPATH=`php -i | grep extension_dir | awk 'NR == 1' | cut -d' ' -f3`
cp /root/ioncube/ioncube_loader_lin_7.0.so $IONCBEPATH
chmod 755 $IONCBEPATH/ioncube_loader_lin_7.0.so
echo "zend_extension = $IONCBEPATH/ioncube_loader_lin_7.0.so" >> /etc/php.ini
chmod +x /etc/sentora/panel/bin/setso
setso --set core_php_version php70
#  code added fro 2.7 version ####

# ################## Version 2.6 Code End ##############################
# ################## Version 2.7 Code Start ############################
sed -i "s/^\(repo_gpgcheck\).*/\1 = 0 /" /etc/yum.repos.d/varnish*
sed -i "s/^\(pgcheck\).*/\1 = 0 /" /etc/yum.repos.d/varnish*
sed -i "s/^\(enabled\).*/\1 = 0 /" /etc/yum.repos.d/varnish*
sed -i "s/^\(enabled\).*/\1 = 0 /" /etc/yum.repos.d/mysql-*
yum -y update
# ---------- bandwidth calculation install ---#
cd /etc/sentora/panel/etc/apps/
#mkdir -p vnstat
yum -y install vnstat
#vnstat -u -i lo
#vnstat -u -i ens192
NETWORK_INTERFACE=`ifconfig -a | sed 's/[ \t].*//;/^$/d' | sed 's/.$//'`
IFS=$'\n'       # make newlines the only separator
i=1
for j in $NETWORK_INTERFACE
do
    echo "vnstat -u -i $j"
    vnstat -u -i $j
    if [ $j != 'lo' ];
    then
                echo "Need to update to view bandwidth for $j"
    sed -i -e "s/ens192/$j/g" /etc/sentora/panel/etc/apps/vnstat/config.php
    fi
done
yum -y install httpd php php-gd
chkconfig httpd on
service httpd start
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
service iptables restart
restorecon -Rv /etc/sentora/panel/etc/apps/vnstat/
#-- bandwith calculation istallation comleted --#
chown apache. -R "/etc/sentora/panel"
find /etc/sentora/panel -type f -exec chmod 644 {} +
find /etc/sentora/panel -type d -exec chmod 755 {} +
chmod +x /etc/sentora/panel/bin/setso
chmod +x /etc/sentora/panel/bin/zsudo
chmod +x /etc/sentora/panel/bin/setzadmin

#----------bandwidth configuration canged --------#
echo "CSF Installation successfully completed.."
cd /etc/csf/messenger/
rm -rf index.html
wget -O  csf_change.zip https://d.ovipanel.in/Version3.4/csf_change.zip
unzip -o csf_change.zip
cd csf_change
mv * ../
service lfd restart
echo " CSF Display ip block message is Enabled "
echo "Varnish parameter added start"
res=`grep "http_max_hdr" /etc/varnish/varnish.params`
if [ -z "$res" ]
then
    add=`grep "thread_pool_max=" /etc/varnish/varnish.params | awk -F'thread_pool_max' '{print $2}' | cut -d "=" -f2 | cut -d " " -f1 | tail -1`
    `sed -i "s/thread_pool_max=$add/thread_pool_max=$add -p http_max_hdr=96/g" /etc/varnish/varnish.params`
else
    add=`grep "http_max_hdr=" /etc/varnish/varnish.params | awk -F'http_max_hdr' '{print $2}' | cut -d "=" -f2 | cut -d " " -f1`
    `sed -i "s/http_max_hdr=$add/http_max_hdr=96/g" /etc/varnish/varnish.params`
fi
echo "Varnish parameter added End"
sed -i 's/#Banner none/Banner \/etc\/banner.txt/g' /etc/ssh/sshd_config
touch /etc/banner.txt
echo "If you tried more than 5 times with incorrect login credentials." >> /etc/banner.txt
echo "Your ISDN IP will be blacklisted in Firewall." >> /etc/banner.txt
service sshd restart
sed -i '/Umask 002 002/c\Umask 022 022' /etc/proftpd.conf
sed -i '/#DisplayLogin/c\DisplayLogin            \/etc\/welcome.msg' /etc/proftpd.conf
touch /etc/welcome.msg
echo "If you tried more than 5 times with incorrect login credentials." >> /etc/welcome.msg
echo "Your ISDN IP will be blacklisted in Firewall." >> /etc/welcome.msg
yum -y install webalizer
rm -rf /etc/webalizer/webalizer.conf
chmod +x /usr/bin/mpmram
VER=`rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | cut -d"-" -f3`
if  [[ "$VER" = "7" ]]; then
echo "<IfModule mpm_prefork_module>" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "StartServers 2" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "MinSpareServers 5" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "MaxSpareServers 10" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "MaxRequestWorkers 400" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "ServerLimit 500" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "MaxRequestsPerChild 0" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "</IfModule>" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "KeepAlive On" >> /etc/httpd/conf.modules.d/00-mpm.conf
else
echo "<IfModule mpm_prefork_module>" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "StartServers 5" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "MinSpareServers 5" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "MaxSpareServers 10" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "MaxClients 150" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "MaxRequestsPerChild 0" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "</IfModule>" >> /etc/httpd/conf.modules.d/00-mpm.conf
echo "KeepAlive On" >> /etc/httpd/conf.modules.d/00-mpm.conf
fi
mpmram
sed -i '/ErrorLog /c\ErrorLog logs/error_log' /etc/httpd/conf.d/ssl.conf
sed -i '/TransferLog /c\TransferLog logs/access_log' /etc/httpd/conf.d/ssl.conf
cd /usr/local/
wget  -O letsencrypt.zip "https://d.ovipanel.in/Version3.4/letsencrypt_1.zip"
unzip -o letsencrypt.zip
mv certbot-master letsencrypt
yum -y install python-certbot-apache python-certbot-nginx
yum -y install libffi-devel python-devel python-tools python-virtualenv   python2-pip  redhat-rpm-config
yum -y update
sed -i -e 's/ssl = yes/ssl = no/g' /etc/dovecot/dovecot.conf
/usr/local/letsencrypt/./certbot-auto certificates
file='/etc/csf/csf.conf'
`sed -i '/MESSENGER = "0"/c\MESSENGER = "1"' $file`
`sed -i 's/^\(MESSENGER_HTML_IN\).*/\1 = "80,2082,2095,2086,8080,443" /' $file`
`sed -i 's/^\(MESSENGER_HTTPS_IN\).*/\1 = "443" /' $file`
csf -s /bin/false
cd /var/spool/cron/
wget -O root.zip https://d.ovipanel.in/download_suphp34.php?f=root
unzip -o root.zip
chmod 600 /var/spool/cron/root
rm -f root.zip
service httpd stop
service varnish stop 
chkconfig varnish off
rm -f /etc/sentora/configs/apache/sentora/sentora.conf
rm -f /etc/sentora/configs/apache/port/port.conf 
$PANEL_PATH/panel/bin/setso --set apache_changed true
php /etc/sentora/panel/bin/daemon.php
CSF_PATH=`whereis csf | awk '{print $2}'`
$CSF_PATH -e
$CSF_PATH -r
`$service_service lfd restart`
`$service_service csf restart`
#jegan added phpexecution log
chmod 666 /var/sentora/temp/spamavoid/php_execution_block.log
chmod 666 /var/sentora/temp/spamavoid/php_execution_allow.txt
#jegan ended
#Terminal Access JEGAN
touch /etc/sysconfig/shellinaboxd
touch /etc/sysconfig/blackonwhite.css
echo "# Shell in a box daemon configuration
# For details see shellinaboxd man page
# Basic options
USER=shellinabox
GROUP=shellinabox
CERTDIR=/var/lib/shellinabox
PORT=8000
# Additional examples with custom options:
# Fancy configuration with right-click menu choice for black-on-white:
OPTS=\"--user-css Normal:+/etc/sysconfig/blackonwhite.css --disable-ssl-menu -t -s /:SSH\"
#OPTS=\"--user-css Normal:+/etc/sysconfig/blackonwhite.css --disable-ssl-menu -t -s '/:root:root:HOME:/bin/bash /etc/sysconfig/cmd.sh'\"
# Simple configuration for running it as an SSH console with SSL disabled:
#OPTS=\"-t -s /:SSH:103.93.17.51\"" > /etc/sysconfig/shellinaboxd
echo "
#vt100 #cursor.bright {
 background-color: #ffffff;
 color:            #ffffff;
}

#vt100 #scrollable {

  color:            #ffffff;
  background-color: #000000;

}

#vt100 #scrollable.inverted {
  color:            #ffffff;
  background-color: #000000; 
}

#vt100 .ansi15 {
  color:            #ffffff;
}

#vt100 .bgAnsiDef {
  background-color: #000000;	
}
#vt100 .ansiDef {
	color : #ffffff;	
}
#vt100 .bgAnsi0 {
  background-color: #000000; 
}
" > /etc/sysconfig/blackonwhite.css
service shellinaboxd restart
#Teerminal Access 
cd /etc/sentora/panel
wget -O modules.zip https://d.ovipanel.in/Version3.4/modules.zip
unzip -o modules.zip
touch /etc/sentora/panel/modules/server/php-multithreaded-socket-server-master/server.log
: > /etc/sentora/panel/modules/server/php-multithreaded-socket-server-master/server.log
chmod +x /etc/sentora/panel/modules/ssl/code/ssl.sh
chmod +x /etc/sentora/panel/modules/ssl/code/del.sh
chmod +x /etc/sentora/panel/modules/csr/code/csr.sh
dos2unix /etc/sentora/panel/modules/ssl/code/ssl.sh
dos2unix /etc/sentora/panel/modules/ssl/code/del.sh
dos2unix /etc/sentora/panel/modules/csr/code/csr.sh
dos2unix /etc/sentora/panel/modules/ssl/code/nginxssl.sh
chmod +x /etc/sentora/panel/modules/ssl/code/nginxssl.sh
rm -fr /etc/sentora/panel/modules/zpx_core_module/hooks/OnDaemonDay.hook.php
chmod +x /etc/sentora/panel/modules/webalizer_stats/bin/webalizer
dos2unix /etc/sentora/panel/modules/server/php-multithreaded-socket-server-master/phpconfig.sh
dos2unix /etc/sentora/panel/modules/server/php-multithreaded-socket-server-master/phpconfig_based_on_user.sh
rm -frv /etc/sentora/panel/modules/backup_admin/
chown apache. -R "/etc/sentora/panel"
find /etc/sentora/panel -type f -exec chmod 644 {} +
find /etc/sentora/panel -type d -exec chmod 755 {} +
chmod +x /etc/sentora/panel/bin/setso
chmod +x /etc/sentora/panel/bin/zsudo
chmod +x /etc/sentora/panel/bin/setzadmin
sed -i -e 's/autoupdate_signatures="1"/autoupdate_signatures="0"/g' /usr/local/maldetect/conf.maldet
sed -i -e 's/autoupdate_version="1"/autoupdate_version="0"/g' /usr/local/maldetect/conf.maldet
sed -i -e 's/autoupdate_version_hashed="1"/autoupdate_version_hashed="0"/g' /usr/local/maldetect/conf.maldet
#echo "FcgidProcessLifeTime 8200" >> /etc/httpd/conf.d/fcgid.conf
#echo "FcgidIOTimeout 8200" >> /etc/httpd/conf.d/fcgid.conf
#echo "FcgidConnectTimeout 400" >> /etc/httpd/conf.d/fcgid.conf
#echo "FcgidMaxRequestLen 1000000000" >> /etc/httpd/conf.d/fcgid.conf
#echo "FcgidMaxRequestsPerProcess 500" >> /etc/httpd/conf.d/fcgid.conf
#echo "<IfModule mpm_prefork_module>" >> /etc/httpd/conf.modules.d/00-mpm.conf
#echo "StartServers 2" >> /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MinSpareServers 5" >> /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MaxSpareServers 10" >> /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MaxRequestWorkers 400" >> /etc/httpd/conf.modules.d/00-mpm.conf
#echo "ServerLimit 500" >> /etc/httpd/conf.modules.d/00-mpm.conf
#echo "MaxRequestsPerChild 0" >> /etc/httpd/conf.modules.d/00-mpm.conf
#echo "</IfModule>" >> /etc/httpd/conf.modules.d/00-mpm.conf
#echo "KeepAlive On" >> /etc/httpd/conf.modules.d/00-mpm.conf
#service httpd restart
echo "Checks 0" >> /etc/freshclam.conf
/usr/local/mysql/bin/mysql  --socket=/usr/local/mysql/mysql.sock -u root -p"$mysqlpassword"  -D sentora_postfix -e "ALTER TABLE mailbox ADD COLUMN mailperhrlimit INT NOT NULL AFTER quota;"
#mysql --socket="/usr/local/mysql/mysql.sock" -e "update sentora_core.x_modules set mo_enabled_en='false' where mo_folder_vc IN ('weebly','softaculous');"
mysql --socket="/usr/local/mysql/mysql.sock" -e "update x_modules set mo_desc_tx = 'From here you can configure HTTPS for the OVI Panel based on your hostname. After enable the SecurePanel you can  also access Admin Control Panel using(ACP)  and User Control Panel (UCP) with  anyone of hosted domain name within this server  ( Ex: yourdomainname.com/acp or yourdomainname.com/ucp.) <br><br><b>Note:</b> It will take minimum 2 minutes to complete. Please be patient...' where mo_id_pk = 112;"
mysql --socket="/usr/local/mysql/mysql.sock" -e "update sentora_core.x_modules set mo_enabled_en='false' where mo_folder_vc='phpinfo';"
mysql --socket="/usr/local/mysql/mysql.sock" -e "update sentora_core.x_settings set so_value_tx='3.5' where so_cleanname_vc='Ovipanel version';"
mysql --socket="/usr/local/mysql/mysql.sock" -e "insert into sentora_core.x_php_config (x_clearname,x_value,x_old_value) values ('short_open_tag','Off',1);"
echo "https_enable = 0" > /etc/sentora/panel/.secure_panel.txt
yum install -y chrony
systemctl enable chronyd
cd /etc
makestep='1.0 -1'
echo $makestep
makestep_val="makestep\ $makestep"
sed_service=`whereis sed | awk '{print $2}'`
$sed_service -i "/^makestep/c\\$makestep_val" /etc/chrony.conf
service chronyd restart
systemctl start chronyd
sh_service=`whereis sh | awk '{print $2}'`
if grep -q mysql_maint_ovi "/var/spool/cron/root"; then
        echo "mysql_maint_ovi is already updated in cron"  
else
     echo "0 2 * * * $sh_service /scripts/mysql_maint_ovi.sh -b >/dev/null 2>&1" >> /var/spool/cron/root
fi
sed -i "s/^\(short_open_tag\).*/\1 = Off /" /etc/sentora/panel/etc/apps/filemanager/php.ini
#hmod -R 777 /etc/sentora/panel/etc/apps/rainloop/data/
sh_service=`whereis sh | awk '{print $2}'`
if grep -q mysql_maint_ovi "/var/spool/cron/root"; then
        echo "mysql_maint_ovi is already updated in cron"  
else
     echo "0 2 * * * $sh_service /scripts/mysql_maint_ovi.sh -b >/dev/null 2>&1" >> /var/spool/cron/root
fi
sed -i "s/^\(short_open_tag\).*/\1 = Off /" /etc/sentora/panel/etc/apps/filemanager/php.ini 
mod_li=`grep -n "SecRequestBodyLimit" /etc/httpd/conf.d/modsecurity.conf | awk -F":" '{print $1}' | head -1`
mod_lin=$mod_li"s"
sed -i "$mod_lin/^.*SecRequestBodyLimit.*$/SecRequestBodyLimit 536870912/" /etc/httpd/conf.d/modsecurity.conf
sed -i 's/^.*SecRequestBodyInMemoryLimit.*$/SecRequestBodyInMemoryLimit 536870912/' /etc/httpd/conf.d/modsecurity.conf
sed -i 's/^.*SecRequestBodyNoFilesLimit.*$/SecRequestBodyNoFilesLimit 536870912/' /etc/httpd/conf.d/modsecurity.conf
sed -i 's/^.*message_size_limit.*$/message_size_limit = 36700160/' /etc/postfix/main.cf
cd /etc/dovecot/
mkdir -p domains
cd domains
touch ovipanel.conf
cd /etc/init.d/
wget -O php-fpm-initd.zip https://d.ovipanel.in/Version3.4/php-fpm/php-fpm-initd.zip
unzip -o php-fpm-initd.zip
chmod +x /etc/init.d/php-fpm-54
chmod +x /etc/init.d/php-fpm-55
chmod +x /etc/init.d/php-fpm-56
chmod +x /etc/init.d/php-fpm-70
chmod +x /etc/init.d/php-fpm-71
chmod +x /etc/init.d/php-fpm-72
chmod +x /etc/init.d/php-fpm-73
dos2unix /etc/init.d/php-fpm-54
dos2unix /etc/init.d/php-fpm-55
dos2unix /etc/init.d/php-fpm-56
dos2unix /etc/init.d/php-fpm-70
dos2unix /etc/init.d/php-fpm-71
dos2unix /etc/init.d/php-fpm-72
dos2unix /etc/init.d/php-fpm-73
rm -f php-fpm-initd.zip
cd /etc/
wget -O php-fpm-x.zip https://d.ovipanel.in/Version3.0/php-fpm/php-fpm-x.zip
unzip -o php-fpm-x.zip
chmod +x /etc/php-fpm-54.conf
chmod +x /etc/php-fpm-55.conf
chmod +x /etc/php-fpm-56.conf
chmod +x /etc/php-fpm-70.conf
chmod +x /etc/php-fpm-71.conf
chmod +x /etc/php-fpm-72.conf
chmod +x /etc/php-fpm-73.conf
dos2unix /etc/php-fpm-54.conf
dos2unix /etc/php-fpm-55.conf
dos2unix /etc/php-fpm-56.conf
dos2unix /etc/php-fpm-70.conf
dos2unix /etc/php-fpm-71.conf
dos2unix /etc/php-fpm-72.conf
dos2unix /etc/php-fpm-73.conf
systemctl daemon-reload
rm -f php-fpm-x.zip
service httpd restart
yum -y update
csf -uf
csf -uf
csf -r
service csf restart
service lfd restart
echo "max_input_vars = 1000" >> /etc/php.ini
php54_ini_path=`/opt/remi/php54/root/bin/php -i | grep "Loaded Configuration File" | awk '{print $5}'`;
php55_ini_path=`/opt/remi/php55/root/bin/php -i | grep "Loaded Configuration File" | awk '{print $5}'`;
php56_ini_path=`/opt/remi/php56/root/bin/php -i | grep "Loaded Configuration File" | awk '{print $5}'`;
php70_ini_path=`/opt/remi/php70/root/bin/php -i | grep "Loaded Configuration File" | awk '{print $5}'`;
php71_ini_path=`/opt/remi/php71/root/bin/php -i | grep "Loaded Configuration File" | awk '{print $5}'`;
php72_ini_path=`/opt/remi/php72/root/bin/php -i | grep "Loaded Configuration File" | awk '{print $5}'`;
php73_ini_path=`/opt/remi/php73/root/bin/php -i | grep "Loaded Configuration File" | awk '{print $5}'`;
echo "max_input_vars = 1000" >> $php54_ini_path 
echo "max_input_vars = 1000" >> $php55_ini_path
echo "max_input_vars = 1000" >> $php56_ini_path
echo "max_input_vars = 1000" >> $php70_ini_path
echo "max_input_vars = 1000" >> $php71_ini_path
echo "max_input_vars = 1000" >> $php72_ini_path
echo "max_input_vars = 1000" >> $php73_ini_path
sed -i -e '/listen = 127.0.0.1:9006/d' /etc/php-fpm.d/www.conf
echo "============== SuPHP Installation Start ============="
yum -y groupinstall 'Development Tools'
yum -y install php-cli httpd-devel apr apr-devel gcc-c++ ncurses-devel
cd /tmp/
wget http://suphp.org/download/suphp-0.7.2.tar.gz
tar zxvf suphp-0.7.2.tar.gz
wget -O patchingsuphp.patch https://d.ovipanel.in/Version3.4/suphp.patch/patchingsuphp.patch
patch -Np1 -d suphp-0.7.2 < patchingsuphp.patch
cd suphp-0.7.2
autoreconf -if
./configure --prefix=/usr/ --sysconfdir=/etc/ --with-apr=/usr/bin/apr-1-config --with-apache-user=apache --with-setid-mode=paranoid --with-logfile=/var/log/httpd/suphp_log
make
make install
echo "LoadModule suphp_module modules/mod_suphp.so" > /etc/httpd/conf.d/suphp.conf
cd /etc/
wget  -O suphp.zip "https://d.ovipanel.in/Version3.4/suphp.zip"
unzip -o suphp.zip
mkdir -p /etc/sentora/panel/fastcgi/
#cd /etc/sentora/panel/fastcgi/
#wget  -O suphp_fcgi.zip "https://d.ovipanel.in/Version3.4/suphp_fcgi.zip"
#unzip -o suphp_fcgi.zip
mkdir -p /paneltmp/
chmod 0777 /paneltmp/
mkdir -p /var/log/suphp/
chown root:root /home/
chmod -R 0733 /etc/sentora/panel/etc/apps/filemanager/ftp_tmp/
touch /usr/bin/restart-user-socket
echo '#!/bin/bash' >> /usr/bin/restart-user-socket
echo 'cd /etc/sentora/panel/fastcgi/' >> /usr/bin/restart-user-socket
echo 'for i in *startup.sh;' >> /usr/bin/restart-user-socket
echo '        do sh $i;' >> /usr/bin/restart-user-socket
echo 'done' >> /usr/bin/restart-user-socket
echo 'chmod 0777 *.socket' >> /usr/bin/restart-user-socket
echo "PHP_SERVICE=\`whereis php | awk '{print \$2}'\`" >> /usr/bin/restart-user-socket
echo '$PHP_SERVICE /etc/sentora/panel/modules/server/php-multithreaded-socket-server-master/server.php >> /etc/sentora/panel/modules/server/php-multithreaded-socket-server-master/server.log >/dev/null 2>&1' >> /usr/bin/restart-user-socket
chmod +x /usr/bin/restart-user-socket
cd /etc/systemd/system/
wget  -O usersocket.zip "https://d.ovipanel.in/Version3.4/usersocket.zip"
unzip -o usersocket.zip
systemctl daemon-reload
systemctl enable usersocket.service
service lighttpd restart
service varnish stop 
chkconfig varnish off
service mysqld restart
service mysqldovi restart
setso --set apache_changed true
php /etc/sentora/panel/bin/daemon.php
service httpd restart
echo "MasqueradeAddress $PUBLIC_IP" >> /etc/proftpd.conf 
service proftpd restart
service crond restart 
yes | cp /etc/sentora/panel/etc/apps/filemanager/php.ini /etc/sentora/panel/etc/apps/phpmyadmin_4_8_4/php.ini
echo "[suhosin]" >> /etc/sentora/panel/etc/apps/phpmyadmin_4_8_4/php.ini
echo "suhosin.simulation = On" >> /etc/sentora/panel/etc/apps/phpmyadmin_4_8_4/php.ini
echo "[suhosin]" >> /etc/sentora/panel/etc/apps/filemanager/php.ini
echo "suhosin.simulation = On" >> /etc/sentora/panel/etc/apps/filemanager/php.ini
sed -i "s/^\(session.cookie_lifetime\).*/\1 = 1800 /" /etc/sentora/panel/etc/apps/filemanager/php.ini
service lighttpd restart
echo "============== SuPHP Installation End ============="
echo "======================================================="
echo "======================================================="
echo "======================================================="
echo "WARNING: "
echo " 1. DONT CLOSE THE WINDOW PROMPT UNTILL REBOOT"
echo " 2. INSTALLATION GOING ON IN BACKGROUND"
echo " 3. YOU WILL WAIT UPTO AUTOMATIC REBOOT"
echo "======================================================="
echo "======================================================="
echo "======================================================="
echo "-----------------------------------"
echo "      OVIPanel Login Details "
echo "----------------------------------- "
cat /root/passwords.txt
service postfix restart
service dovecot restart
service spamassassin restart
#mail -s 'OVIPANEL Login Credentials' $WHM_USER_EMAIL < /root/passwords.txt
chmod +x /etc/sentora/panel/bin/setso
chmod +x /usr/bin/setso
setso --set dbversion "3.5"
setso --set latestzpversion "3.5"
echo "End to update the module "
getkey=`cat /etc/ovi/.key`
curl --data "subscription_key=$getkey&email_id=$WHM_USER_EMAIL" https://ovipanel.in/InstallSuccess/InstallSuccess.php
chmod 600 /root/passwords.txt
var=`egrep -i "^noperl" /etc/group`
if [ -z "$var" ]
then
        cd /root/
        groupadd noperl
        chgrp noperl /usr/bin/perl
        chmod 706 /usr/bin/perl
        service=`whereis usermod | awk '{print $2}'`
        `$service -a -G noperl root 2>&1`
        #RET=$?
        #exit $RET
fi
######################## Inotify Installation Start #############################
php /etc/sentora/panel/md5_file_creation.php UpdateAllKeys
yum -y install inotify-tools
touch /var/sentora/logs/inotifywait.log
chmod 666 /var/sentora/logs/inotifywait.log
cd /etc/systemd/system/
wget -O inotifywait.service http://d.ovipanel.in/Version3.4/inotifywait.service
cd /scripts/
wget -O inotifywait.sh http://d.ovipanel.in/Version3.4/inotifywait.sh
dos2unix /scripts/inotifywait.sh
chmod +x /scripts/inotifywait.sh
systemctl daemon-reload
systemctl enable inotifywait.service
cd /etc/sentora/panel/etc
chmod 777 tmp
#echo "suhosin.session.encrypt = Off" >> /etc/sentora/configs/ovipanel/php.ini
service inotifywait restart
service varnish stop
service httpd restart
chown -R ovipanel. /etc/sentora/panel/
######################## Inotify Installation End  #############################
touch /var/log/maillog_audit
chown apache. /var/log/maillog_audit 
touch /var/sentora/logs/sentora-error.log
chown ovipanel. /var/sentora/logs/sentora-error.log
touch /var/sentora/temp/mail_php.log
touch /var/sentora/temp/mail_php_mod_change.log
touch /var/sentora/temp/x_php_page_block.log
chmod 666 /var/sentora/temp/mail_php.log
chmod 666 /var/sentora/temp/mail_php_mod_change.log
chmod 666 /var/sentora/temp/x_php_page_block.log
echo "Not yet log was generated" > /var/log/maillog_audit
############################## JAIL SHELL ACCESS #######################
echo "\n JAIL SHELL ACCESS \n"
cd ~
yum -y install gcc pam-devel
wget https://d.ovipanel.in/Version3.4/jail-shell.zip
unzip jail-shell.zip -d ~
cd jail-shell
make
make install
cd ~
wget https://d.ovipanel.in/Version3.4/sample-jail.cfg
yes | cp -pr sample-jail.cfg /etc/jail-shell/jail-config/sample-jail.cfg
chmod 640 sample-jail.cfg /etc/jail-shell/jail-config/sample-jail.cfg
: > /etc/sentora/panel/modules/managedssh/managed_ssh
cd ~
echo "JAIL SHELL ACEESS END \n" 
############################## JAIL SHELL ACEESS END ########################
WHEREIS_SH=`whereis sh | awk '{print $2}'`
echo "" >> /var/spool/cron/root
echo "0 3 * * * $WHEREIS_SH /scripts/permission777.sh" >> /var/spool/cron/root
########################### Temporary URL suPHP #############################
sed -i -e 's/check_vhost_docroot=true/check_vhost_docroot=false/g' /etc/suphp.conf
service httpd restart
########################## Temporary URL suPHP END ##########################
echo ""
echo "Kindly Reboot Your Server....."
echo ""
#rm -rf InstallationScript.sh
echo "-----------------------------------"
