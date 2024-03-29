#! /bin/bash


       ## Intro

        # Script by clarsen-007 @ https://github.com/clarsen-007
        # Script is currently only used on Teradata TPA nodes and some TMS servers.
        # Script gatheres some system info and faults, and output is in HTML format.



       ## Variables

        # Version info.
version=00.02.06.04

        # Temp folder for temp data.
tempfolder=/tmp/hscrypt.v2
logfile=/var/log/health.script.log
installfolder=/home/support/system.health.scripts
dumpfolder=/tmp/hscrypt.v2
dumpfile=/tmp/hscrypt.v2/$( /opt/teradata/gsctools/bin/get_siteid ).system.health.report.$( date +%Y%m%d ).log
textfile=/tmp/hscrypt.v2/$(cat /etc/HOSTNAME).system.health.report.txt
gscupload=/root/.upload2gsc

        # Coloring.
rounded_Border_Header=orangered
color_a2_heading_OS=blue
diskspaceheightroot_color=#ebaa60
diskspaceheightvar_color=#0000ff
diskspaceheighttd_color=#77ff00

        # App variable.
keytab=/etc/teradata.keytab
pshwithversion=/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh

        #Users
scpuser=root
btequser=systemfe

        # SCP or UPLOAD2GSC info.
scpkey=
scpipaddress=
scpremotefolder=/home/support/system.health.scripts/import/
upload2gscfolder=/home/support/system.health.scripts/import/

        # Cactus
cactusfile=$(cat /etc/machine-id)
cactus1=U2FsdGVkX1/0suMRlrBXJOcl1FiZQmgTqcfV/+CX4K8YoB1m75cftpCBkfC+X78x

        # Graphs
        ## Available options:
        ## quickchart  ---  Uses https://quickchart.io/ for Graphs
        ## css         ---  Does not work with Outlook, only works with Thunderbird, but looks better
cpugraphtype=quickchart

       ## Installer.
while getopts h:pv option
   do
      case "${option}"
         in
           h) ;;
           p) ;;
           v) ;;
      esac
done


if [ "$1" == "-h" ]
   then
     echo -e " \n "
     echo -e " Usage:[ -h display help text and exit ] "
     echo -e "       [ -p generate encrypted password for variables ] "
     echo -e "       [ -v display version text and exit ] \n"
     exit
fi

if [ "$1" == "-p" ]
   then
     echo -e " "
     read -sp " Password : " varpassword1
     echo -e " "
     echo -e " Encrypted Password below : "
        echo $varpassword1 | openssl enc -aes-256-cbc -salt -a -pass pass:$cactusfile
     echo -e " "
     exit
fi

if [ "$1" == "-v" ]
   then
     echo -e " \n "
     echo -e " Version  =   $version \n "
     exit
fi


       ## Run info.
echo " This script has no real output..."
echo " It is intended to be run from CRON..."
echo -e " Look at logfile $logfile, for errors..."

###########################
#####    Functions.    ####
###########################

######  --- function to run disksum with graph on TMS ---
function TMSDISKSUMGRAPH {
   diskspaceheightroot=$( cat $tempfolder/$servertype.TMS.disk.space.data.usage.txt | \
              grep '/dev/sda' | grep -v '/var' | awk '{print $6}' | cut -d '%' -f1 )
   diskspaceheightvar=$( cat $tempfolder/$servertype.TMS.disk.space.data.usage.txt | \
              grep '/dev/sda' | grep '/var' | grep -v '/var/opt' | awk '{print $6}' | cut -d '%' -f1 )
   diskspaceheighttd=$( cat $tempfolder/$servertype.TMS.disk.space.data.usage.txt | \
              grep '/dev/sda' | grep '/var/opt/teradata' | awk '{print $6}' | cut -d '%' -f1 )

   echo -e "    <div class='a1'>Filesystem usage for $servertype server</div></br> \n" >> $dumpfile
   echo -e "    <svg width='105' height='15'>" >> $dumpfile
   echo -e "        <rect width='100' height='13' rx='5px' \
                     style='fill: rgb(255,255,255) ; \
                     stroke: rgb(0,0,0) ; \
                     stroke-width: 0.3' />" >> $dumpfile
   echo -e "        <rect width='$diskspaceheightroot' height='13' rx='5px' \
                     style='fill: $diskspaceheightroot_color ; \
                     stroke: rgb(0,0,0) ; \
                     stroke-width: 0' />" >> $dumpfile
   echo -e "    </svg>" >> $dumpfile
   echo -e "        <a style='font-size:12px'>/ $diskspaceheightroot%</a>" >> $dumpfile
   echo -e "    </br>" >> $dumpfile

   echo -e "    <svg width='105' height='15'>" >> $dumpfile
   echo -e "        <rect width='100' height='13' rx='5px' \
                     style='fill: rgb(255,255,255) ; \
                     stroke: rgb(0,0,0) ; \
                     stroke-width: 0.3' />" >> $dumpfile
   echo -e "        <rect width='$diskspaceheightvar' height='13' rx='5px' \
                     style='fill: $diskspaceheightvar_color ; \
                     stroke: rgb(0,0,0)' ; \
                     stroke-width: 0' />" >> $dumpfile
   echo -e "    </svg>" >> $dumpfile
   echo -e "        <a style='font-size:12px'>/var $diskspaceheightvar%</a>" >> $dumpfile
   echo -e "    </br>" >> $dumpfile

   echo -e "    <svg width='105' height='15'>" >> $dumpfile
   echo -e "        <rect width='100' height='13' rx='5px' \
                     style='fill: rgb(255,255,255) ; \
                     stroke: rgb(0,0,0) ; \
                     stroke-width: 0.3' />" >> $dumpfile
   echo -e "        <rect width='$diskspaceheighttd' height='13' rx='5px' \
                     style='fill: $diskspaceheighttd_color ; \
                     stroke: rgb(0,0,0)' ; \
                     stroke-width: 0' />" >> $dumpfile
   echo -e "    </svg>" >> $dumpfile
   echo -e "        <a style='font-size:12px'>/var/opt/teradata $diskspaceheighttd%</a>" >> $dumpfile
   echo -e " <pre> \n" >> $dumpfile
   echo -e " </pre> \n" >> $dumpfile
}

######  --- function to run sensor data on TMS ---
function TMSSENSORDATA {
         # Onboard sensors.
         # The SED command here "greps" from the bynet name down to the first space after bynet name.
   echo -e "<div class='a1'>Baseboard sensors:</div>" >> $dumpfile
   echo -e "               <pre> \n" >> $dumpfile
cat $tempfolder/$(cat /etc/HOSTNAME).TMS.sensor.data.txt \
      | sed -n "/localhost/,/^$/p" \
      | egrep 'Fan[0-9]|Temp|Current|Voltage|Mem ECC|Mem CRC|Mem Fatal|Pwr Consumption' \
      | awk -F '|' '{print $1 $2 $3 $4}' \
      | tee -a $dumpfile > /dev/null
   echo -e " <pre> \n" >> $dumpfile
   echo -e " \n" >> $dumpfile
   echo -e " </pre> \n" >> $dumpfile
}



##################################
#####    Functions - Ends.    ####
##################################


       ## Start of script.

        # Clear tmp folder if exist - stale data.
if [ -d $tempfolder ]
         then rm -R $tempfolder
fi

        # Create tmp folder.
if [ ! -d $tempfolder ]
     then mkdir $tempfolder
fi

        # Create log file if not exist - no clearing of file.
if [ -f $logfile ]
     then echo "$(date) :" >> $logfile ; \
     else touch $logfile ; \
          chmod 640 $logfile ; \
          echo "$(date) : " >> $logfile
fi

        # Cleanup of /var/spool/mail/root
if [[ $( find /var/spool/mail/root -type f -size +500M 2>/dev/null ) ]]
     then rm /var/spool/mail/root
fi

        # Create Text and HTML outputs.
echo " " > $dumpfile
echo " " > $textfile

        ## Start script logging
echo "$(date) : *** Script started and logging..." >> $logfile

        # Pre runs.
        # These scrips take long, so running them now in background to eleviate delays.
/opt/teradata/gsctools/bin/find_cmics > $tempfolder/cmics.found.txt &


        # Collect system type from TDput.
servertype=$(cat /etc/opt/teradata/TDput/node_info.txt | grep 'NODETYPE=' | \
     cut -d'=' -f2)
        # Logger
     echo "$(date) : Node type is $servertype." >> $logfile

        # This created the dumpfile output in HTML format.
echo -e " <HTML> \n" >> $dumpfile
echo -e "    <HEAD> \n" >> $dumpfile
echo -e "       <meta http-equiv='Content-Type' content='text/html;charset=ISO-8859-1'> \n" >> $dumpfile

echo -e "    <script type='text/javascript' src='https://www.gstatic.com/charts/loader.js'></script> \n" >> $dumpfile


echo -e "       <STYLE> \n" >> $dumpfile
echo -e "          body { \n" >> $dumpfile
echo -e "              background: white; \n" >> $dumpfile
echo -e "               } \n" >> $dumpfile

        # Font and layout of text body and headers.
echo -e "          .roundedBorderHeader { \n" >> $dumpfile
echo -e "              font-family: Arial; \n" >> $dumpfile
echo -e "              font-size: 40px; \n" >> $dumpfile
echo -e "              color: white; \n" >> $dumpfile
echo -e "              font-weight: bold; \n" >> $dumpfile
echo -e "              height: 50px; \n" >> $dumpfile
echo -e "              min-width: 1000; \n" >> $dumpfile
echo -e "              border: 1px solid $rounded_Border_Header; \n" >> $dumpfile
echo -e "              border-radius: 10px; \n" >> $dumpfile
echo -e "              padding: 2px; \n" >> $dumpfile
echo -e "              background-color: $rounded_Border_Header; \n" >> $dumpfile
echo -e "              line-height: 45px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .roundedBorderInfo { \n" >> $dumpfile
echo -e "              margin: auto; \n" >> $dumpfile
echo -e "              font-family: Courier New; \n" >> $dumpfile
echo -e "              font-size: 10px; \n" >> $dumpfile
echo -e "              padding-top: 5px; \n" >> $dumpfile
echo -e "              padding-right: 5px; \n" >> $dumpfile
echo -e "              padding-bottom: 5px; \n" >> $dumpfile
echo -e "              padding-left: 5px; \n" >> $dumpfile
echo -e "              width: 45%; \n" >> $dumpfile
echo -e "              min-width: 1000px; \n" >> $dumpfile
echo -e "              border-style: solid; \n" >> $dumpfile
echo -e "              border-width: 2px; \n" >> $dumpfile
echo -e "              border-color: orange; \n" >> $dumpfile
echo -e "              border-radius: 10px; \n" >> $dumpfile
echo -e "              align-content: center; \n" >> $dumpfile
echo -e "              pointer-events: none; \n" >> $dumpfile
echo -e "              cursor: default; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .roundedButtonVMS { \n" >> $dumpfile
echo -e "              margin: auto; \n" >> $dumpfile
echo -e "              font-family: Courier New; \n" >> $dumpfile
echo -e "              font-size: 10px; \n" >> $dumpfile
echo -e "              padding-top: 5px; \n" >> $dumpfile
echo -e "              padding-right: 5px; \n" >> $dumpfile
echo -e "              padding-bottom: 5px; \n" >> $dumpfile
echo -e "              padding-left: 5px; \n" >> $dumpfile
echo -e "              max-width: 250px; \n" >> $dumpfile
echo -e "              min-width: 250px; \n" >> $dumpfile
#echo -e "              max-height: 100px; \n" >> $dumpfile
echo -e "              border-style: solid; \n" >> $dumpfile
echo -e "              border-width: 2px; \n" >> $dumpfile
echo -e "              border-color: blue; \n" >> $dumpfile
echo -e "              border-radius: 10px; \n" >> $dumpfile
echo -e "              align-content: center; \n" >> $dumpfile
echo -e "              line-height: 10px; \n" >> $dumpfile
                       # Disabling hyperlinks.
echo -e "              pointer-events: none; \n" >> $dumpfile
echo -e "              cursor: default; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .tableWithBorder { \n" >> $dumpfile
echo -e "              border: 1px solid black; \n" >> $dumpfile
echo -e "              width: 30%; \n" >> $dumpfile
echo -e "              padding: 10px; \n" >> $dumpfile
echo -e "              border-radius: 12px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .tableWithBorder:hover { \n" >> $dumpfile
echo -e "              border: 1px solid black; \n" >> $dumpfile
echo -e "              width: 30%; \n" >> $dumpfile
echo -e "              padding: 10px; \n" >> $dumpfile
echo -e "              border-radius: 12px; \n" >> $dumpfile
echo -e "              box-shadow: 6px 4px 8px 6px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .tableRowForm { \n" >> $dumpfile
echo -e "              transform: scaleY(-1); \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          div.a1 { \n" >> $dumpfile
echo -e "              line-height: normal; \n" >> $dumpfile
echo -e "              font-family: Courier; \n" >> $dumpfile
echo -e "              font-style: normal; \n" >> $dumpfile
echo -e "              font-size: 12px; \n" >> $dumpfile
echo -e "              font-weight: bold; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          div.a2 { \n" >> $dumpfile
echo -e "              font-family: Arial; \n" >> $dumpfile
echo -e "              font-size: 26px; \n" >> $dumpfile
echo -e "              color: $color_a2_heading_OS; \n" >> $dumpfile
echo -e "              font-weight: bold; \n" >> $dumpfile
echo -e "              line-height: normal; \n" >> $dumpfile
echo -e "              font-style: normal; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
                       # New CPU DIVs
echo -e "          .colWrapper { \n" >> $dumpfile
echo -e "              height:110px; \n" >> $dumpfile
echo -e "              width:15px; \n" >> $dumpfile
echo -e "              position:relative; \n" >> $dumpfile
echo -e "              left:20px; \n" >> $dumpfile
echo -e "              bottom:-5px; \n" >> $dumpfile
echo -e "              border:0px solid white; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .nodewindows { \n" >> $dumpfile
echo -e "              width:100%; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .barContainer { \n" >> $dumpfile
echo -e "              position:absolute; \n" >> $dumpfile
echo -e "              bottom:0; \n" >> $dumpfile
echo -e "              width:100%; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .bar { \n" >> $dumpfile
echo -e "              transform: scaleY(-1); \n" >> $dumpfile
echo -e "              width:100%; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
                       # End New CPU DIVs
                       # Y-Axiz CPU Graphs
echo -e "          .baryaxisvalue { \n" >> $dumpfile
echo -e "              padding:0px; \n" >> $dumpfile
echo -e "              border-spacing:0px; \n" >> $dumpfile
echo -e "              left:0px; \n" >> $dumpfile
echo -e "              width:5px; \n" >> $dumpfile
echo -e "              height:5px; \n" >> $dumpfile
echo -e "              font:0.6em Arial; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .baryaxisvalueline { \n" >> $dumpfile
echo -e "              width:2px; \n" >> $dumpfile
echo -e "              height:120px; \n" >> $dumpfile
echo -e "              position:relative; \n" >> $dumpfile
echo -e "              left:15px; \n" >> $dumpfile
#echo -e "              bottom:-10px; \n" >> $dumpfile
echo -e "              bottom:-20px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
                       # X-Axiz CPU Graphs
echo -e "          .cpuaxiz { \n" >> $dumpfile
echo -e "              content:' '; \n" >> $dumpfile
echo -e "              display:block; \n" >> $dumpfile
echo -e "              border:1px solid black; \n" >> $dumpfile
echo -e "              position:relative; \n" >> $dumpfile
echo -e "              top:5px; \n" >> $dumpfile
echo -e "              left:35px; \n" >> $dumpfile
echo -e "              width:490px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxizz { \n" >> $dumpfile
echo -e "              content:' '; \n" >> $dumpfile
echo -e "              display:block; \n" >> $dumpfile
echo -e "              border:0px solid black; \n" >> $dumpfile
echo -e "              position:relative; \n" >> $dumpfile
echo -e "              top:5px; \n" >> $dumpfile
echo -e "              left:15px; \n" >> $dumpfile
echo -e "              width:490px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick { \n" >> $dumpfile
echo -e "              border-left:2px solid black; \n" >> $dumpfile
echo -e "              height:3px; \n" >> $dumpfile
echo -e "              top:0px; \n" >> $dumpfile
echo -e "              position:absolute; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick > span { \n" >> $dumpfile
echo -e "              position:relative; \n" >> $dumpfile
echo -e "              left:0px; \n" >> $dumpfile
echo -e "              font:1em Arial; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile

                 ### Action required please change - create if statment to min on output
echo -e "          .cpuaxiztick:nth-child(1) { \n" >> $dumpfile
echo -e "              left:56px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(2) { \n" >> $dumpfile
echo -e "              left:75px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(3) { \n" >> $dumpfile
echo -e "              left:94px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(4) { \n" >> $dumpfile
echo -e "              left:113px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(5) { \n" >> $dumpfile
echo -e "              left:132px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(6) { \n" >> $dumpfile
echo -e "              left:151px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(7) { \n" >> $dumpfile
echo -e "              left:170px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(8) { \n" >> $dumpfile
echo -e "              left:189px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(9) { \n" >> $dumpfile
echo -e "              left:208px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(10) { \n" >> $dumpfile
echo -e "              left:227px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(11) { \n" >> $dumpfile
echo -e "              left:246px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(12) { \n" >> $dumpfile
echo -e "              left:265px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(13) { \n" >> $dumpfile
echo -e "              left:284px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(14) { \n" >> $dumpfile
echo -e "              left:303px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(15) { \n" >> $dumpfile
echo -e "              left:322px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(16) { \n" >> $dumpfile
echo -e "              left:341px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(17) { \n" >> $dumpfile
echo -e "              left:360px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(18) { \n" >> $dumpfile
echo -e "              left:379px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(19) { \n" >> $dumpfile
echo -e "              left:398px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(20) { \n" >> $dumpfile
echo -e "              left:417px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(21) { \n" >> $dumpfile
echo -e "              left:436px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(22) { \n" >> $dumpfile
echo -e "              left:455px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(23) { \n" >> $dumpfile
echo -e "              left:474px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuaxiztick:nth-child(24) { \n" >> $dumpfile
echo -e "              left:493px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:10px; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
        # CPU Graph title
echo -e "          .cpugraphtitle { \n" >> $dumpfile
echo -e "              position:relative; \n" >> $dumpfile
echo -e "              left:100px; \n" >> $dumpfile
echo -e "              bottom:-10px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:16px; \n" >> $dumpfile
echo -e "              font-weight:bold; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile
echo -e "          .cpuxaxiztitle { \n" >> $dumpfile
echo -e "              position:relative; \n" >> $dumpfile
echo -e "              left:220px; \n" >> $dumpfile
echo -e "              bottom:-20px; \n" >> $dumpfile
echo -e "              font-family:'Courier New'; \n" >> $dumpfile
echo -e "              font-size:13px; \n" >> $dumpfile
echo -e "              font-weight:bold; \n" >> $dumpfile
echo -e "              } \n" >> $dumpfile

echo -e "       </STYLE> \n" >> $dumpfile
echo -e "    </HEAD> \n" >> $dumpfile
echo -e "    <BODY> \n" >> $dumpfile

        # Header
echo -e "       <div class='roundedBorderHeader'> \n" >> $dumpfile
echo -e "       <center> System Health Report </center> \n" >> $dumpfile
echo -e "       </div> \n" >> $dumpfile

        # Scrypt header
echo -e "  <pre>" >> $dumpfile
echo -e "System Health Report for - $(cat /etc/HOSTNAME | cut -d'_' -f1)" >> $dumpfile
echo -e "Version = $version" >> $dumpfile
echo -e "Created by clarsen-007.github.io" >> $dumpfile
echo -e "  </pre>" >> $dumpfile
echo -e " \n" >> $dumpfile

        # Table for System Info and System Summary.
        # First check if system is a Teradata TPA node.
if [ "$servertype" = "TPA" ]
     then (

        # Only run this if the above "if" command is true.
echo -e "       <div class='roundedBorderInfo'> \n" >> $dumpfile
echo -e "       <table style='width:100%'> \n" >> $dumpfile
echo -e "           <tr> \n" >> $dumpfile
echo -e "               <td style='width:70%'> \n" >> $dumpfile

        # System Info header

        # Info - collecting info from machinetype and greping fields out
echo -e "       <pre> \n" >> $dumpfile
echo -e "System info: \n" | tee -a $dumpfile $textfile > /dev/null
     /opt/teradata/gsctools/bin/machinetype | grep 'Model:' -A9 > $tempfolder/shs.systeminfo.log
          if [ ! -f $tempfolder/shs.systeminfo.log ]
               then echo "$(date) : Could not create shs.systeminfo.log." >> $logfile
          fi
        # Grep for outputs and use tee to send output to tw files.
echo -e "$(cat $tempfolder/shs.systeminfo.log | grep 'Model:') \n" | sed '$ {/^$/d;}' | \
     tee -a $dumpfile $tempfolder/server.model.log > /dev/null
echo -e "$(cat $tempfolder/shs.systeminfo.log | grep 'Productid:') \n" | sed '$ {/^$/d;}' | \
     tee -a $dumpfile $tempfolder/server.make.log > /dev/null
echo -e "$(cat $tempfolder/shs.systeminfo.log | grep 'Node:') \n" | sed '$ {/^$/d;}' | \
     tee -a $dumpfile > /dev/null
echo -e "$(cat $tempfolder/shs.systeminfo.log | grep 'Memory:') \n" | sed '$ {/^$/d;}' | \
     tee -a $dumpfile > /dev/null
echo -e "$(cat $tempfolder/shs.systeminfo.log | grep 'Drivers:') \n" | sed '$ {/^$/d;}' | \
     tee -a $dumpfile > /dev/null
echo -e "$(cat $tempfolder/shs.systeminfo.log | grep 'OS:') \n" | sed '$ {/^$/d;}' | \
     tee -a $dumpfile > /dev/null
echo -e "Date:      $(/bin/date) \n" | sed '$ {/^$/d;}' | \
     tee -a $dumpfile > /dev/null
#echo -e " \n" >> $dumpfile
echo -e "       </pre> \n" >> $dumpfile

        # Close System Info header
echo -e "              </td> \n" >> $dumpfile

        # System Summary header
echo -e "              <td style='width:30%'> \n" >> $dumpfile

        # Summary - collecting info from chk_all script (part of GSCTOOLS) 
        # Sending output to file and greping info
        # tee is used to send output to two files
echo -e "       <pre> \n" >> $dumpfile
echo -e "System Summary: \n" | tee -a $dumpfile $textfile > /dev/null
     /opt/teradata/gsctools/bin/chk_all > /dev/null
     head -30 /var/opt/teradata/gsctools/chk_all/chk_all.txt | grep 'SYSTEM SUMMARY:' -A15 > $tempfolder/chk_all.script.out.log
         if [ ! -f $tempfolder/chk_all.script.out.log ]
              then echo "$(date) : Could not create chk_all.script.out.log." >> $logfile
         fi
echo -e "$(cat $tempfolder/chk_all.script.out.log | grep 'SiteID:') \n" | sed '$ {/^$/d;}' \
      | tee -a $dumpfile > /dev/null

if [[ $( cat $tempfolder/chk_all.script.out.log | grep 'System Name:' | cut -d':' -f2 ) == 0 ]]
     then
         echo -e "$(cat $tempfolder/chk_all.script.out.log | grep 'System Name:') <p style='color:red'>System PDN Node has issues...</p> \n" | sed '$ {/^$/d;}' \
                | tee -a $dumpfile > /dev/null
     else
         echo -e "$(cat $tempfolder/chk_all.script.out.log | grep 'System Name:') \n" | sed '$ {/^$/d;}' \
                | tee -a $dumpfile > /dev/null
fi

echo -e "$(cat $tempfolder/chk_all.script.out.log | grep 'DBS Version:') \n" | sed '$ {/^$/d;}' \
      | tee -a $dumpfile > /dev/null
echo -e "$(cat $tempfolder/chk_all.script.out.log | grep 'PDE Version:') \n" | sed '$ {/^$/d;}' \
      | tee -a $dumpfile > /dev/null
echo -e "$(cat $tempfolder/chk_all.script.out.log | grep 'Number of Nodes:') \n" | sed '$ {/^$/d;}' \
      | tee -a $dumpfile > /dev/null
echo -e "$(cat $tempfolder/chk_all.script.out.log | grep 'Number of Cliques:') \n" | sed '$ {/^$/d;}' \
      | tee -a $dumpfile > /dev/null
echo -e "$(cat $tempfolder/chk_all.script.out.log | grep 'Number of AMPs:') \n" | sed '$ {/^$/d;}' \
      | tee -a $dumpfile > /dev/null
echo -e "       </pre> \n" >> $dumpfile

        # Close System Summary header.
echo -e "              </td> \n" >> $dumpfile

        # Close table for System Info and System Summary.
echo -e "          </tr> \n" >> $dumpfile
echo -e "          <tr> \n" >> $dumpfile
echo -e "              <td> \n" >> $dumpfile
echo -e "       <pre> \n" >> $dumpfile
echo -e "COD 'RAW' info: \n" | tee -a $dumpfile > /dev/null
## SED here removes the leading white spaces.
     /opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/pdeglobal tpa \
      | grep 'cpufactor' -A1 | sed 's/^ *//g' >> $dumpfile
echo -e "       </pre> " >> $dumpfile
echo -e "       <pre> \n" >> $dumpfile
     /usr/tdbms/bin/tdwmdmp -a | sed -n '/PSF Global Settings/,/=====================/p' | head -n -2 | sed '/^$/d' >> $dumpfile
echo -e "       </pre> \n" >> $dumpfile
echo -e "       <pre> \n" >> $dumpfile
echo -e "Current TCORE $( su teradata -c '/usr/bin/python /opt/teradata/etcore/tvs_elastic_tcore/etcorecli/etcorecli.py --cmd=get --obj=systemtcore' | cut -d',' -f4 )" >> $dumpfile
echo -e "    Max TCORE $( su teradata -c '/usr/bin/python /opt/teradata/etcore/tvs_elastic_tcore/etcorecli/etcorecli.py --cmd=get --obj=systemtcore' | cut -d',' -f6 ) \n" >> $dumpfile
     /usr/pde/bin/tosgetpma | sed -n '/Processor/,/Memory/p' >> $dumpfile
echo -e " \n" >> $dumpfile
echo -e "IO in Mb/s" >> $dumpfile
     /opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
      "cat /proc/tdmeter/node/mbs | sed '/^$/d'" >> $dumpfile
echo -e "       </pre> \n" >> $dumpfile
echo -e "              </td> \n" >> $dumpfile
echo -e "          </tr> \n" >> $dumpfile
echo -e "       </table> \n" >> $dumpfile
echo -e "       </div> \n" >> $dumpfile

        # Closing the "if" command.
     )
fi

#################################
#### System Type and output #####
#################################


cat /etc/opt/teradata/tdconfig/mpplist | grep byn | awk '{print $1}' > $tempfolder/tpa.mpplist.log
echo -e " <pre> \n" >> $dumpfile
echo -e "List of server(s) in this scripts output... \n" | tee -a $dumpfile $textfile > /dev/null
echo -e "$( cat $tempfolder/tpa.mpplist.log | tr '[:lower:]' '[:upper:]' ) \n" | tee -a $dumpfile $textfile > /dev/null
echo -e " </pre> \n" >> $dumpfile

echo -e "<!--[if IE]> \n" >> $dumpfile
echo -e "<pre>IE</pre> \n" >> $dumpfile
echo -e "<![endif]--> \n" >> $dumpfile

###########################################
##### All scripts for graphing.       #####
##### CPU data.                       #####
##### Gater system type and then do.  #####
###########################################


#############
### TPA  ####
#############

if [ $servertype = "TPA" ]
   then (


echo -e "
#!/bin/bash

tempfolder=/tmp/hscrypt.v2
 
        # Create an array for the 24 hours.
fulldayinhoursarray=( 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 )
        # Then we use array in for loop - we get idle time avarage per hour and devide by 12.
        # Using paste -sd+ to put plus signs inbetween values, and then use bc to do Sum.
   for i in \"\${fulldayinhoursarray[@]}\"
       do echo \$( sar -f /var/log/sa/sa$(date +%Y%m%d -d yesterday) | \\
           egrep \"\$i:[0-5][0-9]:[0-5][0-9]\" | head -12 | grep -v CPU | awk '{print \$8}' | \\
           cut -d'.' -f1 | grep -v 'You have' | paste -sd+ | bc ) / 12 | bc
       done > \$tempfolder/\$(cat /etc/HOSTNAME).cpu.data.idle.time.24hours.txt

        # Now subtract 100 from idle time in 'cpu.data.idle.time.24hours.txt' to get cpu usage.
awk '{print \$1}' \$tempfolder/\$(cat /etc/HOSTNAME).cpu.data.idle.time.24hours.txt | \\
   while read linecpuinput
       do let \" cpuusage = 100 - \$linecpuinput \"
           echo \$cpuusage
       done > \$tempfolder/\$(cat /etc/HOSTNAME).cpu.data.usage.time.24hours.txt
rm \$tempfolder/\$(cat /etc/HOSTNAME).cpu.data.idle.time.24hours.txt

        # Closing echo.
        " > $tempfolder/psh.collect.cpu.info.sh

        # Collecting outputs.
chmod 700 $tempfolder/psh.collect.cpu.info.sh
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "mkdir $tempfolder" > /dev/null 2>&1
echo "$(date) : PCL sending psh.collect.cpu.info.sh for execution on all TPA nodes." >> $logfile
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/pcl -send \
    $tempfolder/psh.collect.cpu.info.sh $tempfolder >> $logfile 2>> $logfile
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "$tempfolder/psh.collect.cpu.info.sh" > /dev/null 2>&1

/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "cat $tempfolder/*.cpu.data.usage.time.24hours.txt" > $tempfolder/ALL.Nodes.cpu.data.usage.time.24hours.txt

        # Drive Space usage.
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "df -hT" > $tempfolder/ALL.Nodes.disk.space.data.usage.time.24hours.txt

        # Server sensor data.
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "/usr/bin/ipmitool sdr" > $tempfolder/ALL.Nodes.sensor.data.txt

       # Server internal Drive data.
servermake=$(cat $tempfolder/server.make.log | cut -d '=' -f5 | grep .)
servermodel=$(cat $tempfolder/server.model.log | awk '{print $2}')

if [ $servermake = "INTEL" ] && [ $servermodel -ne "7011" ]
     then (
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "/opt/MegaRAID/CmdTool2/CmdTool2 -LDPDInfo -a0 \
     | egrep 'Slot Number|Firmware state|Drive Temperature|Drive has flagged'" > \
     $tempfolder/ALL.Nodes.int.drive.info.log
     )
fi

if [ $servermake = "INTEL" ] && [ $servermodel = "7011" ] && [ -f /opt/stack/sbin/storcli ]
     then (
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "/opt/stack/sbin/storcli /c0 /eall /sall show all \
     | egrep 'Drive position|Drive Temperature|252:'" > \
     $tempfolder/ALL.Nodes.int.drive.info.log
     )
fi

if [ $servermake = "INTEL" ] && [ $servermodel = "7011" ] && [ -f /opt/MegaRAID/storcli/storcli64 ]
     then (
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "/opt/MegaRAID/storcli/storcli64 /c0 /eall /sall show all \
     | egrep 'Drive position|Drive Temperature|252:'" > \
     $tempfolder/ALL.Nodes.int.drive.info.log
     )
fi

if [ $servermake = "DELL" ]
     then (
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "/opt/dell/srvadmin/sbin/omreport storage pdisk controller=0 \
     | egrep 'ID|State|Failure Predicted' \
     | egrep -v 'Mirror Set ID|Vendor ID|Non-RAID HDD Disk Cache Policy'" > \
     $tempfolder/ALL.Nodes.int.drive.info.log
     )
fi

       # Processes.
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "/bin/ps axo stat,ppid,pid,comm | grep -w defunct" > $tempfolder/ALL.Nodes.zombie.txt

       # BIOS errors.
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "/usr/bin/ipmitool sel elist | cut -d'|' -f2,4" > \
    $tempfolder/bios.impitool.txt

       # Network Interface info.
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "/opt/teradata/gsctools/bin/netcheck | sed -n '/IFace IP/,/=/p' | grep -v '=' | sed '/^$/d' \
             | grep -v 'is less than the maximum'" > \
    $tempfolder/All.Nodes.nic.info.log


       )
fi

########################################
###### servertype = TPA done...  #######
########################################


#################################
###### servertype = UNITY  ######
#################################

if [ $servertype = "UNITY" ]
   then (

        # Create an array for the 24 hours.
fulldayinhoursarray=( 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 )
        # Then we use array in for loop - we get idle time avarage per hour and devide by 12.
        # Using paste -sd+ to put plus signs inbetween values, and then use bc to do Sum.
   for i in "${fulldayinhoursarray[@]}"
       do echo $( sar -f /var/log/sa/sa$(date +%d -d yesterday) | \
           grep "$i:" | head -12 | grep -v CPU | awk '{print $8}' | \
           cut -d'.' -f1 | grep -v 'You have' | paste -sd+ | bc ) / 12 | bc
       done > $tempfolder/$(cat /etc/HOSTNAME).cpu.data.idle.time.24hours.txt

        # Now subtract 100 from idle time in 'cpu.data.idle.time.24hours.txt' to get cpu usage.
awk '{print $1}' $tempfolder/$(cat /etc/HOSTNAME).cpu.data.idle.time.24hours.txt | \
   while read linecpuinput
       do let " cpuusage = 100 - $linecpuinput "
           echo $cpuusage
       done > $tempfolder/$(cat /etc/HOSTNAME).cpu.data.usage.time.24hours.txt

#cat $tempfolder/$(cat /etc/HOSTNAME).cpu.data.usage.time.24hours.txt >> $dumpfile 


       )
fi

        # Drive Space usage.
echo -e "$(df -hT)" > $tempfolder/$servertype.TMS.disk.space.data.usage.txt

        # Server sensor data.
$pshwithversion \
    "/usr/bin/ipmitool sdr" > $tempfolder/$(cat /etc/HOSTNAME).TMS.sensor.data.txt



###########################################
###### servertype = UNITY done....   ######
###########################################


        ## Creating outputs for the script - one per server.
        # Creating iframe for every server.

###########################################
### CPU Graphs into table - for TPA  ######
###########################################


       ## Collect CPU info from TPA system and output to table format into dumpfile.
# echo -e "       <table style='width:100%'> \n" >> $dumpfile
echo -e "       <table class='nodewindows'> \n" >> $dumpfile
echo -e "           <tr class='nodewindows'> \n" >> $dumpfile
        # Get Nodes for mmplist, the echo displays output next to each other in one line.
      tablenewline=1
for bynname in $( echo $(cat $tempfolder/tpa.mpplist.log) )
   do
echo -e "               <td class='tableWithBorder'> \n" >> $dumpfile &&
echo -e "$servertype Node $bynname \n" >> $dumpfile &&



       ##################


##################
### CSS Graphs ###
##################


if [ $cpugraphtype == 'css' ] ;
   then (

CPUGRAPHDATE=$(date --date="yesterday" +%Y-%m-%d)
echo -e "        <table style='width:100%'><tr class='cpugraphtitle'><td style='text-align:center'>CPU Percentage used for $CPUGRAPHDATE</td></tr></table> \n" >> $dumpfile

echo -e "<table> \n" >> $dumpfile
echo -e "  <tr> \n" >> $dumpfile

echo -e "     <td> \n" >> $dumpfile
        # Y-Axis values - CPU Graph.
echo -e "           <table> \n" >> $dumpfile
echo -e "              <tr class='baryaxisvalue'><td height='10'></td></tr>" >> $dumpfile
echo -e "              <tr class='baryaxisvalue'><td>100</td></tr>" >> $dumpfile
echo -e "              <tr class='baryaxisvalue'><td>80</td></tr>" >> $dumpfile
echo -e "              <tr class='baryaxisvalue'><td>60</td></tr>" >> $dumpfile
echo -e "              <tr class='baryaxisvalue'><td>40</td></tr>" >> $dumpfile
echo -e "              <tr class='baryaxisvalue'><td>20</td></tr>" >> $dumpfile
echo -e "              <tr class='baryaxisvalue'><td>0</td></tr>" >> $dumpfile
echo -e "           </table> \n" >> $dumpfile

echo -e "     </td> \n" >> $dumpfile

echo -e "     <td> \n" >> $dumpfile
echo -e "              <div class='baryaxisvalueline' style='background-color:black;'></div>" >> $dumpfile
echo -e "     </td> \n" >> $dumpfile

       # Out put each Node with previous day (24 hour) CPU load and output to file.
      cat $tempfolder/ALL.Nodes.cpu.data.usage.time.24hours.txt | \
          grep "$bynname" -A25 > $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt
        # Variable to selct line number to start displaying from.
      cputime=1
      xaxis=23
   while [ $cputime -le 24 ]
         do
echo -e "    <td><div class='colWrapper'> \n" >> $dumpfile
echo -e "           <div class='barContainer'> \n" >> $dumpfile

            cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
               grep -v "$bynname" | head -n $cputime | tail -1)
                 if [ $cpuline -lt 10 ]
                    then cpucolor='57,239,5'
                    elif [ $cpuline -lt 20 ]
                       then cpucolor='193,239,5'
                    elif [ $cpuline -lt 30 ]
                       then cpucolor='225,239,5'
                    elif [ $cpuline -lt 40 ]
                       then cpucolor='239,205,5'
                    elif [ $cpuline -lt 50 ]
                       then cpucolor='239,173,5'
                    elif [ $cpuline -lt 60 ]
                       then cpucolor='239,157,5'
                    elif [ $cpuline -lt 70 ]
                       then cpucolor='239,109,5'
                    elif [ $cpuline -lt 80 ]
                       then cpucolor='239,77,5'
                    elif [ $cpuline -lt 90 ]
                       then cpucolor='239,13,5'
                    elif [ $cpuline -lt 101 ]
                       then cpucolor='196,45,196'
                    else cpucolor='0,0,0'
                 fi ;
echo -e "              <div class='bar' style='height:$cpuline\px; background-color:rgb($cpucolor);'></div>" \
               >> $dumpfile
            cputime=$(( $cputime + 1 ))
            xaxis=$(( $xaxis + 15 ))
echo -e "           </div> \n" >> $dumpfile
echo -e "        </div> \n" >> $dumpfile
echo -e "    </td> \n" >> $dumpfile

         done &&
      rm $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt &&


echo -e "  </tr> \n" >> $dumpfile
echo -e "</table>       \n" >> $dumpfile


echo -e "        <table class="cpuaxiz"> \n" >> $dumpfile
echo -e "        </table> \n" >> $dumpfile

echo -e "        <table class="cpuaxizz"> \n" >> $dumpfile
echo -e "           <tr> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>1</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>2</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>3</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>4</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>5</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>6</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>7</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>8</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>9</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>10</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>11</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>12</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>13</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>14</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>15</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>16</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>17</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>18</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>19</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>20</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>21</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>22</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>23</span></td> \n" >> $dumpfile
echo -e "               <td class='cpuaxiztick'><span>24</span></td> \n" >> $dumpfile
echo -e "           </tr> \n" >> $dumpfile
echo -e "        </table> \n" >> $dumpfile
echo -e "        <div class='cpuxaxiztitle'><span>Hour of the day</span></div> \n" >> $dumpfile
echo -e "</br> \n" >> $dumpfile ;


######################################
### DiskSpace Graphs into table ######
######################################

echo -e "               <div> \n" >> $dumpfile

diskspaceheightroot=$( cat $tempfolder/ALL.Nodes.disk.space.data.usage.time.24hours.txt | grep '$bynname ' -A8 | \
              grep '/dev/sda' | grep -v '/var' | awk '{print $6}' | cut -d '%' -f1 )
diskspaceheightvar=$( cat $tempfolder/ALL.Nodes.disk.space.data.usage.time.24hours.txt | grep '$bynname ' -A8 | \
              grep '/dev/sda' | grep '/var' | grep -v '/var/opt' | awk '{print $6}' | cut -d '%' -f1 )
diskspaceheighttd=$( cat $tempfolder/ALL.Nodes.disk.space.data.usage.time.24hours.txt | grep '$bynname ' -A8 | \
              grep '/dev/sda' | grep '/var/opt/teradata' | awk '{print $6}' | cut -d '%' -f1 )

echo -e "    <font>Filesystem usage for TPA server $bynname</font></br> \n" >> $dumpfile
echo -e "    <svg width='105' height='15'>" >> $dumpfile
echo -e "        <rect width='100' height='13' rx='5px' \
                     style='fill: rgb(255,255,255) ; \
                     stroke: rgb(0,0,0) ; \
                     stroke-width: 0.3' />" >> $dumpfile
echo -e "        <rect width='$diskspaceheightroot' height='13' rx='5px' \
                     style='fill: rgb(235,170,96) ; \
                     stroke: rgb(0,0,0) ; \
                     stroke-width: 0' />" >> $dumpfile
echo -e "    </svg>" >> $dumpfile
echo -e "        <a style='font-size:12px'>/ $diskspaceheightroot%</a>" >> $dumpfile
echo -e "    </br>" >> $dumpfile


echo -e "    <svg width='105' height='15'>" >> $dumpfile
echo -e "        <rect width='100' height='13' rx='5px' \
                     style='fill: rgb(255,255,255) ; \
                     stroke: rgb(0,0,0) ; \
                     stroke-width: 0.3' />" >> $dumpfile
echo -e "        <rect width='$diskspaceheightvar' height='13' rx='5px' \
                     style='fill: rgb(0,0,255) ; \
                     stroke: rgb(0,0,0)' ; \
                     stroke-width: 0' />" >> $dumpfile
echo -e "    </svg>" >> $dumpfile
echo -e "        <a style='font-size:12px'>/var $diskspaceheightvar%</a>" >> $dumpfile
echo -e "    </br>" >> $dumpfile


echo -e "    <svg width='105' height='15'>" >> $dumpfile
echo -e "        <rect width='100' height='13' rx='5px' \
                     style='fill: rgb(255,255,255) ; \
                     stroke: rgb(0,0,0) ; \
                     stroke-width: 0.3' />" >> $dumpfile
echo -e "        <rect width='$diskspaceheighttd' height='13' rx='5px' \
                     style='fill: rgb(0,0,255) ; \
                     stroke: rgb(0,0,0)' ; \
                     stroke-width: 0' />" >> $dumpfile
echo -e "    </svg>" >> $dumpfile
echo -e "        <a style='font-size:12px'>/var/opt/teradata $diskspaceheighttd%</a>" >> $dumpfile
echo -e "               </div> \n" >> $dumpfile


        )
fi ;


#############################
### Quickcharts.io Graphs ###
#############################


if [ $cpugraphtype == 'quickchart' ] ;
   then (

       # Out put each Node with previous day (24 hour) CPU load and output to file.
      cat $tempfolder/ALL.Nodes.cpu.data.usage.time.24hours.txt | \
          grep "$bynname" -A25 > $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt
        # Variable to selct line number to start displaying from.
      cputime=1
      CPUGRAPHDATE=$(date --date="yesterday" +%Y-%m-%d)

echo -e "
<img src=\"https://quickchart.io/chart?width=300&height=150&c=
{
  type: 'bar',
  data: {
        labels: [ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24' ],
        datasets: [{
              label: 'CPU Percentage used for $CPUGRAPHDATE', " >> $dumpfile
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     data: [ $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline, " >> $dumpfile
cputime=$(( $cputime + 1 ))
cpuline=$(cat $tempfolder/$bynname.node.cpu.data.usage.time.24hours.txt | \
    grep -v "$bynname" | head -n $cputime | tail -1)
echo -e "     $cpuline ] " >> $dumpfile
echo -e "    },
    ]
  }
} \"> " >> $dumpfile ;


######################################
### DiskSpace Graphs into table ######
######################################


diskspaceheightroot=$( cat $tempfolder/ALL.Nodes.disk.space.data.usage.time.24hours.txt | grep $bynname -A8 | \
              grep '/dev/sda' | grep -v '/var' | awk '{print $6}' | cut -d '%' -f1 )
diskspaceheightvar=$( cat $tempfolder/ALL.Nodes.disk.space.data.usage.time.24hours.txt | grep $bynname -A8 | \
              grep '/dev/sda' | grep '/var' | grep -v '/var/opt' | awk '{print $6}' | cut -d '%' -f1 )
diskspaceheighttd=$( cat $tempfolder/ALL.Nodes.disk.space.data.usage.time.24hours.txt | grep $bynname -A8 | \
              grep '/dev/sda' | grep '/var/opt/teradata' | awk '{print $6}' | cut -d '%' -f1 )


echo -e "
<img src=\"https://quickchart.io/chart?width=300&height=150&c=
{
  type: 'polarArea',
  data: {
    datasets: [
      {
        data: [ $diskspaceheightroot , $diskspaceheightvar , $diskspaceheighttd ],
        backgroundColor: [
          'rgba(54, 162, 235, 0.5)',
          'rgba(75, 192, 192, 0.5)',
          'rgba(253, 173, 92, 0.5)',
        ],
        label: 'My dataset',
      },
    ],
    labels: ['/', '/var', '/var/opt/teradata'],
  },
  options: {
    legend: {
      position: 'right',
    },
    title: {
      display: true,
      text: 'Filesystem usage for TPA server $bynname',
      fontSize: 10,
    },
  },
}  \"> " >> $dumpfile
 
        )
fi ;


echo -e "               <pre>" >> $dumpfile
echo -e "               </pre> \n" >> $dumpfile


##############################
##### Sensor Data start. #####
##############################

         # Onboard sensors.
         # The SED command here "greps" from the bynet name down to the first space after bynet name.
echo -e "<div class='a1'>Baseboard sensors:</div>" >> $dumpfile
echo -e "               <pre> \n" >> $dumpfile
cat $tempfolder/ALL.Nodes.sensor.data.txt \
     | sed -n "/$bynname /,/^$/p" \
     | egrep 'Fan[0-9]|Fan [0-9]|Temp|Current|Voltage|PS|Mem ECC|Mem CRC|Mem Fatal|Pwr Consumption|Airflow' \
     | grep -v 'Fan [0-9] Present' \
     | awk -F '|' '{print $1 $2 $3 $4}' \
     | tee -a $dumpfile $textfile > /dev/null
echo -e "               </pre> \n" >> $dumpfile



         # Internal drives.
         # The first SED command here "greps" from the bynet name down to the first space after bynet name.
         # The second SED command here, removes first line from output.
echo -e "<div class='a1'>Internal Drives:</div>" >> $dumpfile
echo -e "               <pre> \n" >> $dumpfile
cat $tempfolder/ALL.Nodes.int.drive.info.log  \
     | sed -n "/$bynname /,/^$/p" \
     | sed '1d' \
     | tee -a $dumpfile $textfile > /dev/null
echo -e "               </pre> \n" >> $dumpfile


         # Network Interface info.
echo -e "<div class='a1'>Network Interface info:</div>" >> $dumpfile
echo -e "               <pre> \n" >> $dumpfile
cat $tempfolder/All.Nodes.nic.info.log \
     | sed -n "/$bynname /,/^$/p" \
     | sed '1d' \
     | tee -a $dumpfile > /dev/null
echo -e "               </pre> \n" >> $dumpfile

         # Infiniband card info
echo -e "<div class='a1'>Infiniband Card info:</div>" >> $dumpfile
echo -e "               <pre> \n" >> $dumpfile
/usr/sbin/ibstatus | grep 'Infini\|state\|phys\|rate' | grep -v 'link_layer' \
     | tee -a $dumpfile $tempfolder/ibinfo.main.txt > /dev/null
echo -e "               </pre> \n" >> $dumpfile


         # BIOS errors.
echo -e "<div class='a1'>BIOS errors:</div>" >> $dumpfile
echo -e "               <pre> \n" >> $dumpfile
tail -5 $tempfolder/bios.impitool.txt \
     | tee -a $dumpfile > /dev/null
echo -e "               </pre> \n" >> $dumpfile


############################
##### Sensor Data end. #####
############################



###############################
##### Closing Table data. #####
###############################

echo -e "               </td> \n" >> $dumpfile
      if [ $tablenewline -eq 3 ]
         then
echo -e "           </tr> \n" >> $dumpfile
echo -e "           <tr> \n" >> $dumpfile
        # if tablenewline = 4 then restart loop for <tr>.
      elif [ $tablenewline -eq 4 ]
         then tablenewline=1
      fi ;
      tablenewline=$(( $tablenewline + 1 ))
   done
echo -e "           </tr> \n" >> $dumpfile
echo -e "           </table> \n" >> $dumpfile


########################################
##### Closed Table data - for TPA  #####
########################################


#############################################
### CPU Graphs into table - for UNITY  ######
#############################################


if [ $servertype = "UNITY" ]
   then (

       ## Collect CPU info from UNITY and output to table format into dumpfile.
echo -e "       <table style='width:100%'> \n" >> $dumpfile
echo -e "           <tr'> \n" >> $dumpfile
echo -e "               <td class='tableWithBorder'> \n" >> $dumpfile &&
echo -e "TMS $(cat /etc/HOSTNAME) \n" >> $dumpfile &&
echo -e "               <div class='tableRowForm'> \n" >> $dumpfile &&
echo -e "               <svg width='400' height='140'> \n" >> $dumpfile &&
echo -e "                  <line x1='15' y1='20' x2='381' y2='20' style='stroke:rgb(0,0,0);stroke-width:2'></line> \
     \n" >> $dumpfile &&
echo -e "                  <line x1='20' y1='15' x2='20' y2='123' style='stroke:rgb(0,0,0);stroke-width:2'></line> \
     \n" >> $dumpfile &&
echo -e "                  <line x1='15' y1='123' x2='21' y2='123' style='stroke:rgb(0,0,0);stroke-width:2'></line> \
     \n" >> $dumpfile &&
echo -e "                  <line x1='381' y1='21' x2='381' y2='15' style='stroke:rgb(0,0,0);stroke-width:2'></line> \
     \n" >> $dumpfile &&
      cpuperline=123
   while [ $cpuperline -ge 33 ]
         do
   echo -e "                  <line x1='23' y1='$cpuperline' x2='381' y2='$cpuperline' style='stroke:rgb(240,240,240);stroke-width:1'></line>" \
         >> $dumpfile &&
            cpuperline=$(( $cpuperline - 10 ))
         done &&
        # Out put each Node with previous day (24 hour) CPU load and output to file.
        # Variable to selct line number to start displaying from.
      cputime=1
      xaxis=23
   while [ $cputime -le 24 ]
         do
            cpuline=$(cat $tempfolder/$(cat /etc/HOSTNAME).cpu.data.usage.time.24hours.txt | \
               head -n $cputime | tail -1)
                 if [ $cpuline -lt 10 ]
                    then cpucolor='57,239,5'
                    elif [ $cpuline -lt 20 ]
                       then cpucolor='193,239,5'
                    elif [ $cpuline -lt 30 ]
                       then cpucolor='225,239,5'
                    elif [ $cpuline -lt 40 ]
                       then cpucolor='239,205,5'
                    elif [ $cpuline -lt 50 ]
                       then cpucolor='239,173,5'
                    elif [ $cpuline -lt 60 ]
                       then cpucolor='239,157,5'
                    elif [ $cpuline -lt 70 ]
                       then cpucolor='239,109,5'
                    elif [ $cpuline -lt 80 ]
                       then cpucolor='239,77,5'
                    elif [ $cpuline -lt 90 ]
                       then cpucolor='239,13,5'
                    elif [ $cpuline -lt 101 ]
                       then cpucolor='196,45,196'
                    else cpucolor='0,0,0'
                 fi ;
   echo -e "                  <rect width='13' height='$cpuline' x='$xaxis' y='23' style='fill:rgb($cpucolor);stroke-width:0'></rect>" \
               >> $dumpfile
            cputime=$(( $cputime + 1 ))
            xaxis=$(( $xaxis + 15 ))
         done &&
      rm $tempfolder/$(cat /etc/HOSTNAME).cpu.data.usage.time.24hours.txt &&
echo -e "Sorry, your browser or mail client, does not support inline SVG... \n" >> $dumpfile
echo -e "               </svg> \n" >> $dumpfile
echo -e "               </div> \n" >> $dumpfile


######  Diskspace Unity start ########


echo -e "               <div> \n" >> $dumpfile

TMSDISKSUMGRAPH

echo -e "               </div> \n" >> $dumpfile

######  Diskspace Unity end ########

######  Sensor data Unity start ########


echo -e "               <div> \n" >> $dumpfile

TMSSENSORDATA

echo -e "               </div> \n" >> $dumpfile

######  Sensor data Unity end ########


echo -e "               </td> \n" >> $dumpfile
echo -e "           </tr> \n" >> $dumpfile
echo -e "           </table> \n" >> $dumpfile

       )
fi


##########################################
##### Closed Table data - for UNITY  #####
##########################################







#######################
### Global scripts. ###
#######################


#########################################
### Total system - OS related issues. ###
#########################################

echo -e " \n" >> $dumpfile
echo -e "<center><div class='a2'> \n" >> $dumpfile
echo -e "   <center>** OS Info **</center> \n" >> $dumpfile
echo -e "</div></center> \n" >> $dumpfile
echo -e " \n" >> $dumpfile

##### Process info. #####

          # Zombie processes.
echo -e "<div class='a1'>Zombie processes:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

cat $tempfolder/ALL.Nodes.zombie.txt \
    | tee -a $dumpfile $textfile > /dev/null

   )
fi
echo -e "               </pre> \n" >> $dumpfile


### Checking to see if PDE is up.

echo -e "<div class='a1'>PDE / DBS Status:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
    "/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/pdestate -a" \
    | sed '1d' \
    | tee -a $dumpfile $textfile > /dev/null

   )
fi
echo -e "           </pre> \n" >> $dumpfile


### Check for any down AMP's or Nodes.

echo -e "<div class='a1'>AMP / Node Status:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

/opt/teradata/tdat/tdbms/$(/usr/pde/bin/pdepath -i | grep 'TDBMS:' | cut -d' ' -f2)/bin/vprocmanager -g \
     | egrep 'AMP |RSG |GTW |TVS |PE ' | grep -v 'ONLINE' | grep -v 'Vproc' \
     | tee -a $tempfolder/down.amps.txt > /dev/null
 # Checking if file is empty - if it is empty then echo the ok.
 if [[ -s $down.amps.txt/down.amps.txt ]]
    then echo -e "*****There are Down AMPs*****\n Following AMPs are down:\n " \
       | tee -a $dumpfile $textfile > /dev/null
         cat $tempfolder/down.amps.txt \
            | tee -a $dumpfile $textfile > /dev/null
    else echo "All AMPs seems to be ONLINE" \
       | tee -a $dumpfile $textfile > /dev/null
 fi
   rm $tempfolder/down.amps.txt
   )
fi
echo -e "           </pre> \n" >> $dumpfile


### Checking date on all servers.

echo -e "<div class='a1'>Date:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh /bin/date \
     > $tempfolder/shs.date.log
   cat $tempfolder/shs.date.log | tee -a $dumpfile $textfile > /dev/null
   rm $tempfolder/shs.date.log
   )
fi
echo -e "           </pre> \n" >> $dumpfile


### NTP status.

echo -e "<div class='a1'>NTP status:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh "/usr/sbin/ntpq -p | grep '*'" \
     > $tempfolder/ntp.server.status.log
 # sed $ removes empty lines s and g teplace string with string
   cat $tempfolder/ntp.server.status.log | sed '/^$/d' | sed 's/---------------------//g' | sed 's/-----------//g' \
         | sed 's/</-/g' | sed 's/>//g' \
         | tee -a $dumpfile $textfile > /dev/null
   rm $tempfolder/ntp.server.status.log
   )
fi
echo -e "           </pre> \n" >> $dumpfile


### Looking for any system dumps.

echo -e "<div class='a1'>System dumps:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

echo -e "Dumps on Node...." >> $dumpfile
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/csp -mode list \
     > $tempfolder/shs.csp.log
   cat $tempfolder/shs.csp.log | tee -a $dumpfile > /dev/null
   rm $tempfolder/shs.csp.log ;

sleep 2 ;
echo -e " " >> $dumpfile

echo -e "Dumps in Database...." >> $dumpfile
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/csp -mode list -source table \
     > $tempfolder/shs.csp.log
   cat $tempfolder/shs.csp.log | tee -a $dumpfile > /dev/null
   rm $tempfolder/shs.csp.log

   )
fi
echo -e "           </pre> \n" >> $dumpfile


### Database start time.

echo -e "<div class='a1'>Database start time:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/tpatrace -s | grep PDE \
     > $tempfolder/shs.trace.log
   cat $tempfolder/shs.trace.log | tee -a $dumpfile $textfile > /dev/null
   rm $tempfolder/shs.trace.log
   )
fi
echo -e "           </pre> \n" >> $dumpfile


### Test DNS.

echo -e "<div class='a1'>DNS Test:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh \
     /usr/bin/dig google.com | grep 'google.com' | grep -v '\;' > $tempfolder/dns.test.log
   cat $tempfolder/dns.test.log | tee -a $dumpfile $textfile > /dev/null
   rm $tempfolder/dns.test.log
   )
fi
echo -e "           </pre> \n" >> $dumpfile


### Active Directory Logon Test.

echo -e "<div class='a1'>Active Directory Logon Test:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

/opt/teradata/tdat/tdgss/$(rpm -qa | grep tdgss | sort | tail -1 | cut -d'-' -f2)/bin/tdsbind -u SA23360003 -w \
     $(cat /etc/lp.dat) > $tempfolder/ad.test.log
   cat /tmp/ad.test.log \
      | grep -v ' FQDN:' \
      | grep -v 'LdapServiceFQDN' \
      | grep -v 'AuthUser' \
      | tee -a $dumpfile $textfile > /dev/null
   )
fi
echo -e "           </pre> \n" >> $dumpfile


### Kerberos Authentication Test.

echo -e "<div class='a1'>Kerberos Authentication Test:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

/usr/lib/mit/bin/klist -ke $keytab | grep -i cop \
     | tee -a $dumpfile $tempfolder/krlist.out.txt > /dev/null
        sleep 2
            for i in $(cat $tempfolder/krlist.out.txt | sed -e 's/^[[:space:]]*//' \
                | cut -d' ' -f2 | cut -d'@' -f1) ; \
                    do /usr/lib/mit/bin/kvno $i ; \
            done > $tempfolder/krlist.out.2.txt
   cat $tempfolder/krlist.out.2.txt | tee -a $dumpfile $textfile > /dev/null
   )
fi
echo -e "           </pre> \n" >> $dumpfile


### GetHost output for Kerberos.

echo -e "<div class='a1'>GetHost test for Kerberos:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

for i in $(cat $tempfolder/krlist.out.2.txt | cut -d' ' -f1 | cut -d'/' -f2 |  cut -d'@' -f1)
   do /opt/teradata/tdat/tdgss/$(/usr/pde/bin/pdepath -i | grep 'TDBMS:' | cut -d' ' -f2)/bin/gethost -c $i ;
   done | grep 'TERADATA' > $tempfolder/krlist.out.3.txt
   cat $tempfolder/krlist.out.3.txt | sed 's/^ *//g' | tee -a $dumpfile $textfile > /dev/null
rm $tempfolder/krlist.out*.txt
   )
fi
echo -e "           </pre> \n" >> $dumpfile

### Array health output.

echo -e "<div class='a1'>Array health:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (

#What array is being used
/opt/teradata/gsctools/bin/machinetype | grep "SCSI:" | grep -o "LSI" \
     | sort -u >> $tempfolder/system.health.array_type.txt
/opt/teradata/gsctools/bin/machinetype | grep "SCSI:" | grep -o "NETAPP" \
     | sed "s/NETAPP/LSI/g" | sort -u >> $tempfolder/system.health.array_type.txt
/opt/teradata/gsctools/bin/machinetype | grep "SCSI:" | grep -o "DotHill" \
     | sort -u >> $tempfolder/system.health.array_type.txt

 while read array_type1 ;
 do if [ "$array_type1" = "LSI" ] ;
 then
     (

#Running LSI array checks
/opt/teradata/tdat/pde/$(/usr/pde/bin/pdepath -i | grep PDE: | cut -d' ' -f2)/bin/psh "/usr/bin/SMcli -d -v" \
     | sed '/SMcli completed successfully/d' | sed '/^$/d' | column -t | sort -u | grep -v -i 'byn\|all' \
     | tee -a $dumpfile $tempfolder/SM.output.health.txt > /dev/null
cat $tempfolder/SM.output.health.txt | awk '!/byn0/' \
     | grep 'Need' \
     | cut -d' ' -f1 > $tempfolder/faulty.array.list.txt
if [[ -s $tempfolder/faulty.array.list.txt ]]
 then echo -e "\n*****There are Faults in the Arrays*****\n       Faulty Array list... \n$(cat $tempfolder/faulty.array.list.txt)\n" \
     | tee -a $dumpfile $textfile > /dev/null
 else echo -e "\n*****All Array are Healthy*****\n" | tee -a $dumpfile $textfile > /dev/null
fi
while read in
 do SMcli -n "$in" -c 'show storageArray healthStatus;'
 done < $tempfolder/faulty.array.list.txt \
     | sed '/Performing syntax check.../d' \
     | sed '/Syntax check complete./d' \
     | sed '/Executing script.../d' \
     | sed '/Script execution complete./d' \
     | sed '/SMcli completed successfully./d' \
     | sed '/The controller clocks/d' \
     | sed '/Controller/d' \
     | sed '/Storage Management Station/d' \
     | sed '/^$/d' \
     | tee -a $dumpfile $textfile > /dev/null

     )
 fi ;  done < $tempfolder/system.health.array_type.txt

 while read array_type1 ;
 do if [ "$array_type1" = "DotHill" ] ;
 then
     (

#Running DotHill array checks
#Run chk_array script
/opt/teradata/gsctools/bin/chk_array

  #Extract raw DAMC outputs from text file
  /bin/cat /var/opt/teradata/gsctools/chk_array/data/chk_array.txt | grep "DAMC" -A5 > $tempfolder/system.health.chk_array1.txt
  #Use grep and sed to remove info
  /bin/cat $tempfolder/system.health.chk_array1.txt | sed '/###################/d' > $tempfolder/system.health.chk_array2.txt
  /bin/cat $tempfolder/system.health.chk_array2.txt | grep 'DAMC' | sort -u > $tempfolder/system.health.chk_array3.txt
  /bin/cat $tempfolder/system.health.chk_array3.txt | sed 's/^[^:]*://' | sed -e 's/^[ \t]*//' > $tempfolder/system.health.chk_array4.txt
  while read pat ; do grep -m 1 "$pat" $tempfolder/system.health.chk_array2.txt -A5 ; done < $tempfolder/system.health.chk_array4.txt > $tempfolder/system.health.chk_array5.txt
  /bin/cat $tempfolder/system.health.chk_array5.txt | sed '/Vendor:/d' | sed '/Prodid:/d' | sed '/MidPlaine_SN:/d' | sed '/Enclosure Count:/d' \
       | tee -a $dumpfile $textfile > /dev/null

#Display faulty drives:
cat /var/opt/teradata/gsctools/chk_array/data/chk_array.txt | grep 'HITACHI HUC' | grep -i -v 'OK' \
    | tee -a $dumpfile $textfile > /dev/null

     )
 fi ;
done < $tempfolder/system.health.array_type.txt

   )
fi
echo -e "           </pre> \n" >> $dumpfile

### Infiniband Info.

echo -e "<div class='a1'>Infiniband Info:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile
if [ $servertype = "TPA" ]
   then (
cat $tempfolder/ibinfo.main.txt | grep 'mlx' | sort | uniq -c | cut -d"'" -f2 \
    | tee -a $tempfolder/switch.fabrics.txt > /dev/null
  for i in $(sed -n 1p $tempfolder/switch.fabrics.txt) $(sed -n 2p $tempfolder/switch.fabrics.txt) ;
     do /opt/teradata/bynet/bin/ibinfo -P 1 -C $i -d netinfo allswitches \
    | tee -a $dumpfile > /dev/null
  done ;
     )
fi
echo -e "           </pre> \n" >> $dumpfile


### CPU and AWT SQL

if [ $servertype = "TPA" ]
   then (
echo -e "<div class='a1'>Database CPU and AWT data:</div>" >> $dumpfile
echo -e "           <pre> \n" >> $dumpfile

/usr/bin/bteq <<EOI
.logon /$btequser,$( echo $cactus1 | openssl enc -aes-256-cbc -salt -a -d -pass pass:$cactusfile );
.export report file=$tempfolder/cpuawt.csv
.width 2000

SELECT THEDATE,  EXTRACT ( HOUR FROM (( TheTime ))) AS Starthour
    ,WM_COD_CPU
    ,CAST ( SUM ( CPUIDLE + CPUIOWAIT + CPUUSERV + CPUUEXEC ) AS BIGINT ) / 100 as MaxCPUSeconds
    ,CAST ( MaxCPUSeconds / 1000 * WM_COD_CPU AS INTEGER ) AS WMCODSeconds
    ,CAST ( SUM ( CPUUSERV + CPUUEXEC ) AS INTEGER ) /100 AS CPUSecondsConsumed
    ,CPUSecondsConsumed*100/WMCODSeconds as Percent_Consumed
    ,MAX( AwtInuseMax ) AS AwtInuseMax
    ,MAX( AmpsFlowControlled ) AS AmpsFlowControlled
FROM  dbc.ResUsageSpma                 
WHERE THEDATE = date -1
GROUP BY 1,2,3
ORDER BY 1,2;

.export reset
.logoff
.exit
EOI

cat $tempfolder/cpuawt.csv | tee -a $dumpfile > /dev/null
# rm $tempfolder/cpuawt.csv
    )
fi
echo -e "           </pre> \n" >> $dumpfile


#########################
##########TESTS##########
#########################

#
#
#
#
#

echo -e "This is a test area.... no live data in this section \n" >> $dumpfile

echo -e "
<img src=\"https://quickchart.io/chart?width=500&height=300&c=
{
  type: 'line',
  data: {
    labels: [
      [
        'June',
        '2015'
      ],
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
      [
        'January',
        '2016'
      ],
      'February',
      'March',
      'April',
      'May'
    ],
    'datasets': [
      {
        label: 'Dispatcher AWT',
        fill: false,
        backgroundColor: 'rgb(255, 99, 132)',
        borderColor: 'rgb(255, 99, 132)',
        data: [
          13,
          40,
          45,
          30,
          87,
          72,
          77,
          45,
          18,
          20,
          94,
          64
        ]
      },
      {
        label: 'Max AWT in use',
        fill: false,
        backgroundColor: 'rgb(255, 255, 132)',
        borderColor: 'rgb(255, 255, 132)',
        data: [
          93,
          90,
          95,
          80,
          67,
          42,
          47,
          25,
          78,
          90,
          74,
          44
        ]
      },
      {
        label: 'Flowcontrol',
        fill: false,
        backgroundColor: 'rgb(54, 162, 235)',
        borderColor: 'rgb(54, 162, 235)',
        data: [
          90,
          51,
          56,
          60,
          62,
          21,
          20,
          74,
          81,
          35,
          35,
          56
        ]
      }
    ]
  },
  options: {
    responsive: true,
    title: {
      display: true,
      text: 'Chart with Multiline Labels'
    }
  }
}  \"> " >> $dumpfile

echo -e "Test area.... over \n" >> $dumpfile


#########################
#########TESTS END#######
#########################



        # VMS and CMIC info.
echo -e "       <div class='roundedButtonVMS'> \n" >> $dumpfile
echo -e "       <pre> \n" >> $dumpfile
echo -e "VMS and CMIC versions: \n" | tee -a $dumpfile $textfile > /dev/null
/usr/bin/timeout 30s /opt/teradata/gsctools/bin/get_cmic_version > $tempfolder/cmic.ver.txt
/usr/bin/timeout 30s /opt/teradata/gsctools/bin/vmscmd vmsutil -v | grep 'VMS Version:' > $tempfolder/vms.ver.txt
echo -e "CMIC Version:          $(cat $tempfolder/cmic.ver.txt) \n" | tee -a $dumpfile $textfile > /dev/null
echo -e "$(cat $tempfolder/vms.ver.txt | cut -d'(' -f1) \n" | tee -a $dumpfile $textfile > /dev/null
         if [ ! -f $tempfolder/cmics.found.txt ]
              then sleep 10 ; echo "$(date) : Could not find CMIC heartbeats - sleeping 10 seconds - and retry" >> \
                   $logfile
         fi
echo -e "CMIC's found - \n" | tee -a $dumpfile $textfile > /dev/null
echo -e "$(grep -v -F 'Listening' < $tempfolder/cmics.found.txt) \n" | tee -a $dumpfile $textfile > /dev/null
rm $tempfolder/cmic.ver.txt
rm $tempfolder/vms.ver.txt
rm $tempfolder/cmics.found.txt
echo -e "        </pre> \n" >> $dumpfile
echo -e "        </div> \n" >> $dumpfile

#########################################
### Send all outputs to text log file ###
#########################################

       ## Sending info to text output file
       # First cleaning up file.
sed -i '/^$/d' $textfile

       # Then send output from TPA scripts.
sed 's/--//g' $tempfolder/ALL.Nodes.cpu.data.usage.time.24hours.txt >> $textfile


###########################################
##### All scripts for graphing.       #####
##### Done....                        #####
###########################################





       ## Messages from /var/log/messages
        # WARNINGS
echo -e "        <pre> \n" >> $dumpfile
echo -e "<p style='font-weight:bold; color:blue'> Warnings: </p> \n" | tee -a $dumpfile $textfile > /dev/null

        # Dump messages file.
cat /var/log/messages | egrep "`date --date="yesterday" +%Y-%m-%d`|`date +%Y-%m-%d`" | grep -i 'warning' > \
     $tempfolder/warning.messages.txt

        # Removing messages that can be ignored.
cat $tempfolder/warning.messages.txt | \
     grep -v '9470: Warning: DBQL XMLPLAN/STATSUSAGE' \
     grep -v 'WARNING: DBSControl is running in System FE' \
     | tee -a $dumpfile $textfile > /dev/null

        # Next check if error 9470 was present and how many times.
cat $tempfolder/warning.messages.txt | grep '9470: Warning: DBQL XMLPLAN/STATSUSAGE' | wc -l > \
     $tempfolder/9470.txt
if [ -z $(grep "0" "$tempfolder/9470.txt") ];
     then echo -e " \n" | tee -a $dumpfile $textfile > /dev/nul && \
          echo "<p style='color:blue'>  ---  9470: Warning: DBQL XMLPLAN/STATSUSAGR displayed $(cat $tempfolder/9470.txt) times </p>" \
              | tee -a $dumpfile $textfile > /dev/null && \
          echo -e "         ---  Information, can be ignored - fixed in TDBMS version 16.20.25.01 (KB0030015) \n" \
              | tee -a $dumpfile $textfile > /dev/null
fi

        # Next check if INFO message 2900 was present and how many times.
cat $tempfolder/warning.messages.txt | grep 'WARNING: DBSControl is running in System FE' | wc -l > \
     $tempfolder/2900.txt
if [ -z $(grep "0" "$tempfolder/2900.txt") ];
     then echo -e " \n" | tee -a $dumpfile $textfile > /dev/nul && \
          echo "<p style='color:blue'>  ---  2900: WARNING: DBSControl is running in System FE mode displayed $(cat $tempfolder/2900.txt) times </p>" \
              | tee -a $dumpfile $textfile > /dev/null && \
          echo -e "         ---  Information, can be ignored - there are monitoring scripts, accessing dbscontrol settings periodically (RECJ4445X) \n" \
              | tee -a $dumpfile $textfile > /dev/null
fi

        # Cleanup of messages output files.
rm $tempfolder/warning.messages.txt
rm $tempfolder/9470.txt
rm $tempfolder/2900.txt



        ##### FAILURES
echo -e "<p style='font-weight:bold; color:orange'> Failures: </p> \n" | tee -a $dumpfile $textfile > /dev/null
        # Dump messages file.
cat /var/log/messages | egrep "`date --date="yesterday" +%Y-%m-%d`|`date +%Y-%m-%d`" | grep -i 'fail' > \
     $tempfolder/failures.messages.txt
        # Removing messages that can be ignored.
cat $tempfolder/failures.messages.txt \
     | grep -v 'Logon Failed' \
     | grep -v 'Logon Authentication Failed' \
     | grep -v 'Eventtype: Logon failed' \
     | grep -v 'Eventtype: Auth failed' \
     | grep -v 'LDAP failure has occurred' \
     | grep -v 'TDGSS Authentication failed' \
     | grep -v 'Failed authentication User Account' \
     | tee -a $dumpfile $textfile > /dev/null
        # Next check for message 'Logon Failed'
cat $tempfolder/failures.messages.txt | grep 'Logon Failed' | wc -l > \
     $tempfolder/logonfailed.txt
if [ -z $(grep "0" "$tempfolder/logonfailed.txt") ];
     then echo -e " \n" | tee -a $dumpfile $textfile > /dev/nul && \
          echo "<p style='color:orange'>  ---  Teradata: Logon Failed displayed $(cat $tempfolder/logonfailed.txt) times </p>" \
              | tee -a $dumpfile $textfile > /dev/null && \
          echo -e "         ---  Information, can be ignored - incorrect user credentials provided, when attempting logon \n" \
              | tee -a $dumpfile $textfile > /dev/null
fi



        # ERRORS
echo -e "<p style='font-weight:bold; color:red'>Errors: </p> \n" | tee -a $dumpfile $textfile > /dev/null
cat /var/log/messages | egrep "`date --date="yesterday" +%Y-%m-%d`|`date +%Y-%m-%d`" | grep -i 'error' | tee -a $dumpfile $textfile > /dev/null

         # ABORTED
echo -e " Aborted Sessions: \n" | tee -a $dumpfile $textfile > /dev/null
cat /var/log/messages | egrep "`date --date="yesterday" +%Y-%m-%d`|`date +%Y-%m-%d`" | grep -i 'Transaction has been Aborted' -A3 | tee -a $dumpfile $textfile > /dev/null

         # UCAbort
echo -e "<p style='font-weight:bold; color:blue'> UCAbort: </p> \n" | tee -a $dumpfile $textfile > /dev/null
cat /var/log/messages | egrep "`date --date="yesterday" +%Y-%m-%d`|`date +%Y-%m-%d`" | grep -i 'UCAbort' > \
     $tempfolder/UCAbort.messages.txt

        # Removing messages that can be ignored.
cat $tempfolder/UCAbort.messages.txt | \
     grep -v 'OldState is CS_LOGOFFRSPOKINTRAN, Network Event is CE_LOGOFFMSGRSPOK, NewState is CS_OFFWAITUCABTRSP' \
     | tee -a $dumpfile $textfile > /dev/null

cat $tempfolder/UCAbort.messages.txt | grep 'OldState is CS_LOGOFFRSPOKINTRAN, Network Event is CE_LOGOFFMSGRSPOK, NewState is CS_OFFWAITUCABTRSP' | wc -l > \
     $tempfolder/UCAbort1.txt
if [ -z $(grep "0" "$tempfolder/UCAbort1.txt") ];
     then echo -e " \n" | tee -a $dumpfile $textfile > /dev/nul && \
          echo "<p style='color:blue'>  ---  Sending UCAbort message to the database for Session displayed $(cat $tempfolder/UCAbort1.txt) times </p>" \
              | tee -a $dumpfile $textfile > /dev/null && \
          echo -e "         ---  Information, can be ignored - CS_LOGOFFRSPOKINTRAN, CE_LOGOFFMSGRSPOK, CS_OFFWAITUCABTRSP - from DataLabs (KB0028808)  \n" \
              | tee -a $dumpfile $textfile > /dev/null
fi

        # Cleanup of messages output files.
rm $tempfolder/UCAbort.messages.txt
rm $tempfolder/UCAbort1.txt

echo -e "        </pre> \n" >> $dumpfile




       ## Testing section.
# cat /var/opt/teradata/gsctools/chk_all/chk_all.txt | grep "pdepath_chk" -A11 | sort -u


        # Ending dumpfile.
echo -e "    </BODY> \n" >> $dumpfile
echo -e " </HTML> \n" >> $dumpfile


       ## Cleanup of output file.
        # Send file to e-mail server.
        # Key
/usr/bin/scp -i $scpkey $dumpfile $scpuser@$scpipaddress:$scpremotefolder > /dev/null 2>&1
        # No Key
/usr/bin/scp $dumpfile $scpuser@$scpipaddress:$scpremotefolder > /dev/null 2>&1
     if [ $? -eq 0 ]
          then echo "$(date) : Successfully send output file to E-mail server." >> $logfile
          else echo "$(date) : Failed to send output file to E-mail server." >> $logfile
     fi

/usr/bin/scp $textfile $scpuser@$scpipaddress:$scpremotefolder > /dev/null 2>&1
     if [ $? -eq 0 ]
          then echo "$(date) : Successfully send text file to E-mail server." >> $logfile
          else echo "$(date) : Failed to send text file to E-mail server." >> $logfile
     fi

       ## Sending file via UPLOAD2GSC

echo -e "SiteID=AXYZ01
Name=AA123456
Phone=99999
Email=AA123456@Teradata.com
Proxy=
NAT=
Cipher=aes256
Axeda=
AxedaOnCMIC=
AxedaGTW=
AxedaUser= " > $gscupload

/opt/teradata/gsctools/bin/upload2gsc -d -i CS1234567 $dumpfile

#############################################
##### Cleanup old log and output files  #####
#############################################

     rm $tempfolder/chk_all.script.out.log
     rm $tempfolder/shs.systeminfo.log



        # Make Text output file - more readable.
awk 'NF > 0' $textfile > $tempfolder/pre.out.master.txt
     sleep 1
     mv $tempfolder/pre.out.master.txt $textfile

# Remeber to add line below at end to make file nice and readable and keep on system for viewing, currently it is only nice in e-mail form.
# Add zombie processes and more.
# If put output else and not Teradata installed in script


##############################
##### Script History.... #####
##############################

##
## 00.02.06.00
## Added TCORE and other COD values.
##
## 00.02.05.00
## Added and modified to CPU and Disk Graphs.
## Added Quickchart and renamed previous Graphs to CSS.
## Changed default Graphs to Quickchart, as it works in MS Outlook.
##
## 00.02.04.04
## Added / Updated CSP Dumps to show Node and Database Dumps.
##
## 00.02.04.03
## Fix date issue for messages files on SLES12
##
## 00.02.04.02
## Fix spelling mistake - under Array health.
##
## 00.02.04.01
## Bug fix - /var/spool/mail/root excessive logging.
## Added process to clear space for root
##
## 00.02.04.00
## Added CPU and AWT SQL for TPA nodes.
##
## 00.02.03.01
## Fixed incorrect CPU graphs
## Mofified Infiniband output - cosmetic.
##
## 00.02.03.00
## Added more sensor output in server section.
## Fixed BIOS output in server section.
##
## 00.02.02.02
## Bug fixes.
## Added COD info.
## Added Infiniband switch and card info.
##
## 00.02.02.01
## Added fan speed info.
##
## 00.02.02.00
## Adding Unity and BAR.
##
## 00.02.01.06
## Added network info.
##
## 00.02.01.05
## Added NETAPP array to testing array health.
##
## 00.02.01.04
## Fixed up some outputs from messages file in the "FAILURES" section.
## cosmetic changes to output and added coloring in variables.
## Added some support for 7011 ( Intelliflex 2.1 ).
##
## 00.02.01.03
## Fixed up some outputs from messages file in the "WARNINGS" section.
##
## 00.02.01.02
## Added Array test.
##
## 00.02.01.01
## Added Kerberos testing.
## Tasks
##  -- Added proper logging.
##  -- Fix TEXT version - output needs attention.
##
## 00.02.00.00
## Total redesign and initial release.
