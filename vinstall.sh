read -e -p "Enter Your Subscription Key:" SUB_KEY
DIRECTORY="/etc/ovi/"
if [ ! -d "$DIRECTORY" ]; then
   mkdir $DIRECTORY
fi
cd $DIRECTORY
file=".key"
if [ ! -f "$file" ]
then
    touch $file
fi
echo $SUB_KEY > $file
#server_ip=`hostname -I | awk '{print $1}'`
server_ip="$(wget -qO- http://ipecho.net/plain -q -O -)"
if [ "$server_ip" == "127.0.0.1" ]
then
        server_ip=`hostname -I | awk '{print $2}'`
fi
cd /root/
DOS=`whereis dos2unix | awk '{print $2}'`
if [ "$DOS" == "" ]; then
   yum -y install dos2unix
fi
#!/usr/bin/env bash
extern_ip="$(wget -qO- http://ipecho.net/plain -q -O -)"
#extern_ip=`dig +short myip.opendns.com @resolver1.opendns.com`
#local_ip=$(ifconfig eth0 | sed -En 's|.*inet [^0-9]*(([0-9]*\.){3}[0-9]*).*$|\1|p')
local_ip=$(ip addr show | awk '$1 == "inet" && $3 == "brd" { sub (/\/.*/,""); print $2 }')
while getopts d:i:t: opt; do
  case $opt in
  d)
      PANEL_FQDN=$OPTARG
      INSTALL="auto"
      ;;
  i)
      PUBLIC_IP=$OPTARG
      if [[ "$PUBLIC_IP" == "local" ]] ; then
          PUBLIC_IP=$local_ip
      elif [[ "$PUBLIC_IP" == "public" ]] ; then
          PUBLIC_IP=$extern_ip
      fi
      ;;
  t)
      echo "$OPTARG" > /etc/timezone
      tz=$(cat /etc/timezone)
      ;;
  esac
done
if [[ ("$PANEL_FQDN" != "" && "$PUBLIC_IP" == "") ||
      ("$PANEL_FQDN" == "" && "$PUBLIC_IP" != "") ]] ; then
    echo "-d and -i must be both present or both absent."
    exit 2
fi
<<COMMENT1
if [[ "$tz" == "" && "$PANEL_FQDN" == "" ]] ; then
    # Propose selection list for the time zone
    echo "Preparing to select timezone, please wait a few seconds..."
    $PACKAGE_INSTALLER tzdata
    # setup server timezone
    if [[ "$OS" = "CentOs" ]]; then
        # make tzselect to save TZ in /etc/timezone
        echo "echo \$TZ > /etc/timezone" >> /usr/bin/tzselect
        tzselect
        tz=$(cat /etc/timezone)
    elif [[ "$OS" = "Ubuntu" ]]; then
        dpkg-reconfigure tzdata
        tz=$(cat /etc/timezone)
    fi
fi
# clear timezone information to focus user on important notice
COMMENT1
rm -fr /etc/localtime
cp /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
clear

loop_enter_valid_email=1
while test $loop_enter_valid_email = 1
do
echo "Enter the client email address for WHM User :"
read WHM_USER_EMAIL
regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
        if [[ $WHM_USER_EMAIL =~ $regex ]] ; then
                loop_enter_valid_email=0
        else
                echo "Email is invalid"
        fi
done
if [[ "$PANEL_FQDN" == "" ]] ; then
 echo -e "\n\e[1;33m=== Informations required to build your server ===\e[0m"
    echo 'The installer requires 2 pieces of information:'
    echo ' 1) the sub-domain that you want to use to access OVI panel,'
    echo '   - do not use your main domain (like domain.com)'
    echo '   - use a sub-domain, e.g panel.domain.com'
    echo '   - or use the server hostname, e.g server1.domain.com'
    echo '   - DNS must already be configured and pointing to the server IP'
    echo '       for this sub-domain'
    echo ' 2) The public IP of the server.'
    echo ''

    PANEL_FQDN="$(/bin/hostname)"
    PUBLIC_IP=$extern_ip
    while true; do
        echo ""
        read -e -p "Enter the sub-domain you want to access OVI panel: " -i "$PANEL_FQDN" PANEL_FQDN

        if [[ "$PUBLIC_IP" != "$local_ip" ]]; then
          echo -e "\nThe public IP of the server is $PUBLIC_IP. Its local IP is $local_ip"
          echo "  For a production server, the PUBLIC IP must be used."
        fi
        read -e -p "Enter (or confirm) the public IP for this server: " -i "$PUBLIC_IP" PUBLIC_IP
        echo ""

        # Checks if the panel domain is a subdomain
        sub=$(echo "$PANEL_FQDN" | sed -n 's|\(.*\)\..*\..*|\1|p')
        if [[ "$sub" == "" ]]; then
            echo -e "\e[1;31mWARNING: $PANEL_FQDN is not a subdomain!\e[0m"
            echo "  If you want later you can change your sub-domain $PANEL_FQDN."
            confirm="true"
        fi
		# Checks if the panel domain is already assigned in DNS
        dns_panel_ip=$(hostname "$PANEL_FQDN"|grep address|cut -d" " -f4)
        if [[ "$dns_panel_ip" == "" ]]; then
            echo -e "\e[1;31mWARNING: $PANEL_FQDN is not defined in your DNS!\e[0m"
            echo "  You must add records in your DNS manager (and then wait until propagation is done)."
            echo "  If this is a production installation, set the DNS up as soon as possible."
            echo "  If you want later you can change your sub-domain $PANEL_FQDN."
            confirm="true"
        else
            echo -e "\e[1;32mOK\e[0m: DNS successfully resolves $PANEL_FQDN to $dns_panel_ip"

            # Check if panel domain matches public IP
            if [[ "$dns_panel_ip" != "$PUBLIC_IP" ]]; then
                echo -e -n "\e[1;31mWARNING: $PANEL_FQDN DNS record does not point to $PUBLIC_IP!\e[0m"
                echo "  OVI will not be reachable from http://$PANEL_FQDN"
                confirm="true"
                         fi
        fi

        if [[ "$PUBLIC_IP" != "$extern_ip" && "$PUBLIC_IP" != "$local_ip" ]]; then
            echo -e -n "\e[1;31mWARNING: $PUBLIC_IP does not match detected IP !\e[0m"
            echo "  OVI Panel will not work with this IP..."
                confirm="true"
        fi
		echo ""
        # if any warning, ask confirmation to continue or propose to change
        if [[ "$confirm" != "" ]] ; then
            echo "There are some warnings..."
            echo "Are you really sure that you want to setup OVI Panel with these parameters?"
            read -e -p "All is ok. Do you want to install OVI Panel now (y/n)? " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) exit;;
            esac
        fi
    done
fi
if [[ "$WHM_USER_EMAIL" != "" && "$PANEL_FQDN" != "" && "$PUBLIC_IP" != "" && "$confirm" != "" && "$yn" != "" ]]; then
	wget -O InstallationScript.sh "https://raw.githubusercontent.com/anamwdiz/TrPanel/master/InstallationScript.sh"
	dos2unix InstallationScript.sh
	con=`cat InstallationScript.sh`
	if [ "$con" == "Your Subscription Key Invalid or Already Used" ]
	then
        	echo "$con"
        	rm -rf /root/InstallationScript.sh
        	exit
	fi
	yum -y install screen
	SH_PATH=`whereis sh | awk '{print $2}'`
	SCREEN=`whereis screen | awk '{print $2}'`
	if [ "$SCREEN" == "" ]; then
		yum -y install screen
		SCREEN=`whereis screen | awk '{print $2}'`
	fi
	GREP=`whereis grep | awk '{print $2}'`
	screen_name="InstallOviPanel"
	SCREEN_RESULT=`$SCREEN -list | $GREP $screen_name`
	if [ "$SCREEN_RESULT" == "" ]; then
		echo $SCREEN
		`$SCREEN -d -m -S $screen_name $SH_PATH -c " $SH_PATH /root/InstallationScript.sh $WHM_USER_EMAIL $PANEL_FQDN $PUBLIC_IP $confirm $yn; rm -rf /root/InstallationScript.sh; "`
		echo "======================================================="
		echo "Your Installation going on screen if you want know the status run the commands .."
		echo "screen -ls"
		echo "screen -root screen name"
		echo "======================================================="
		#$SH_PATH /root/InstallationScript.sh $WHM_USER_EMAIL $PANEL_FQDN $PUBLIC_IP $confirm $yn
		#rm -rf /root/InstallationScript.sh
	fi
else
        echo "Some values are missing.."
fi
