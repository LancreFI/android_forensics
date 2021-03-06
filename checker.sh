#/bin/sh
##PRESET VARIABLES
ANDVRS=$(adb shell getprop ro.build.version.sdk)
DEVSNO=$(adb get-serialno)
DEVNFO="android_devinfo_$DEVSNO"
ADB_BACKUP="android_adb_backup_$DEVSNO"
CHECKSUMS="android_checksums_$DEVSNO"
PROCLIST="android_process_list_$DEVSNO"
UPROCLIST="android_user_process_list_$DEVSNO"
LOGFILE="android_log_$DEVSNO"
LOGFILE_ERRORS="android_log_errors_$DEVSNO"
STORAGE_LIST="android_storage_list_$DEVSNO"
INTRST=(apk jar)
INTRST_LIST="android_storage_interesting_$DEVSNO"
rm "$INTRST_LIST" 2>/dev/null
NETSTATS="android_netstat_$DEVSNO"
rm "$NETSTATS" 2>/dev/null
PKGS="android_installed_packages_$DEVSNO"

##TERMINAL COLORS
RED="\033[1;31m"
GRN="\033[1;32m"
WHT="\033[1;37m"
YLW="\033[1;33m"
RSTCOL="\033[0m"

echo " "
echo -e "${RED}   [     THE SCRIPT GETS DATA AUTOMATICALLY, BUT FOR THE     ]"
echo -e "   [ LOGICAL BACKUP YOU NEED TO UNLOCK THE PHONE WHEN ASKED! ]"
echo " "

echo -e "${WHT}Checking if we've got root access..."
if adb shell su 2> /dev/null
then
	if adb shell ls -al data 2>/dev/null
	then
		echo -e "${RSTCOL}|  ${YLW}'--> ${RED}ROOTED!"
	fi
else
	echo -e "${RSTCOL}|  ${YLW}'--> ${GRN}NOT ROOTED!"
	echo -e "${RSTCOL}|  ${YLW}      '--> ${WHT}Creating a logical, non-invasive backup...${RSTCOL}"

	adb backup -all -f "$ADB_BACKUP" |sed -e 's/^/|\x1b[1;31m              /'
	echo -e "${RSTCOL}|  ${YLW}            '--> ${GRN}Backup ${YLW}$ADB_BACKUP${GRN} created!"
	echo -e "${RSTCOL}|  ${YLW}            '--> ${WHT}Calculating MD5..."
	md5sum "$ADB_BACKUP" > "$CHECKSUMS"
	echo -e "${RSTCOL}|  ${YLW}                  '--> ${GRN}Saved to ${YLW}$CHECKSUMS${GRN}!"
fi
echo -e "${RSTCOL}|"

echo -e "${WHT}Getting device info..."
echo "Device serial number:	$DEVSNO" > "$DEVNFO"
echo "Android version:	$ANDVRS" >> "$DEVNFO"
if [[ $(adb shell locksettings verify 2>/dev/null) ]]
then
        echo -e "${RSTCOL}|  ${YLW}|    ${GRN}The device has no lock code, it's already unlocked${GRN}!"
        echo "Lock screen:      	No password detected!" >> "$DEVNFO"
else
        echo -e "${RSTCOL}|  ${YLW}|    ${RED}The device has a PIN/pass/pattern protected lock screen${GRN}!"
        echo "Lock screen:	      Locked with a PIN/pass/pattern!" >> "$DEVNFO"
fi
echo -e "${RSTCOL}|  ${YLW}'--> ${GRN}Saved to ${YLW}$DEVNFO${GRN}!"
echo -e "${RSTCOL}|"

echo -e "${WHT}Listing running processes..."
adb shell ps -A > "$PROCLIST"
echo -e "${RSTCOL}|  ${YLW}'--> ${GRN}Running processes listed in ${YLW}$PROCLIST${GRN}!"
echo -e "${RSTCOL}|"

echo -e "${WHT}Listing processes being run by the user..."
echo "USER           PID  PPID     VSZ    RSS WCHAN            ADDR S NAME" > "$UPROCLIST"
grep u[0-9]_[a-z][0-9].* "$PROCLIST" >> "$UPROCLIST"
echo -e "${RSTCOL}|  ${YLW}'--> ${GRN}Running user processes listed in ${YLW}$UPROCLIST${GRN}!"
echo -e "${RSTCOL}|"

echo -e "${WHT}Getting device's connections and routing table..."
echo "Device $DEVSNO routing table:" >> "$NETSTATS"
adb shell netstat -r >> "$NETSTATS"
echo " " >> "$NETSTATS"
adb shell netstat -aep >> "$NETSTATS" 2>> "$NETSTATS"
echo -e "${RSTCOL}|  ${YLW}'--> ${GRN}Device netstats saved to ${YLW}$NETSTATS${GRN}!"
echo -e "${RSTCOL}|"

echo -e "${WHT}Dumping device log to $LOGFILE..."
adb logcat -d > "$LOGFILE"
echo -e "${RSTCOL}|  ${YLW}'--> ${GRN}Done! Wrote $(wc -l $LOGFILE|sed 's/ .*//') rows to ${YLW}$LOGFILE${GRN}!"
echo -e "${RSTCOL}|"

echo -e "${WHT}Skimming errors from the log..."
cat "$LOGFILE"|grep " E " > "$LOGFILE_ERRORS"
echo -e "${RSTCOL}|  ${YLW}'--> ${GRN}Found $(wc -l $LOGFILE_ERRORS|sed 's/ .*//') rows of errors and wrote them to ${YLW}$LOGFILE_ERRORS${GRN}!"
echo -e "${RSTCOL}| "

echo -e "${WHT}Getting info of all applications..."
echo "##All packages: " > "$PKGS""_temp"
adb shell pm list packages >> "$PKGS""_temp"
echo "##Third party packages: " >> "$PKGS""_temp"
adb shell pm list packages -3 >> "$PKGS""_temp"
echo "##Disabled packages: " >> "$PKGS""_temp"
adb shell pm list packages -d >> "$PKGS""_temp"
adb shell dumpsys package packages >> "$PKGS""_temp"
echo "##Packages to consider inspecting closer:" > "$PKGS"
INTRST_PKGS=($(grep installerPackage "$PKGS""_temp"|grep -v "com.android.vending"|sed 's/^.*=//g'))
INTRST_PKGSR=($(grep -n installerPackage "$PKGS""_temp"|grep -v "com.android.vending"|sed 's/:.*$//g'))
if [ "${#INTRST_PKGSR[@]}" -gt 0 ]
then
	for instrow in "${INTRST_PKGSR[@]}"
	do
		INSTROW="$instrow"
		MATCH=0
		COUNTER=0
		while [ "$MATCH" == 0 ]
		do
			PKG_NAME=$(sed -n "$INSTROW"p "$PKGS""_temp" |grep "^  Package ")
			let "INSTROW-=1"
			if [[ ! -z "$PKG_NAME" ]]
			then
				echo "$PKG_NAME installed using ${INTRST_PKGS[$COUNTER]}" >> "$PKGS"
				((COUNTER+=1))
				MATCH=1
			fi
		done
	done
fi
echo -e "${RSTCOL}|  ${YLW}'--> ${RED}Packages to consider inspecting closer:${RSTCOL}"
tail -n +2 "$PKGS"|sed -e 's/^/\x1b[0m|\x1b[1;33m  |  /'
cat "$PKGS""_temp" >> "$PKGS"
echo -e "${RSTCOL}|  ${YLW}'--> ${GRN}Saved to ${YLW}$PKGS${GRN}!"
rm "$PKGS""_temp"
echo -e "${RSTCOL}|"

echo -e "${WHT}Listing storage content..."
adb shell ls -RLal storage > "$STORAGE_LIST" 2>/dev/null
echo -e "${RSTCOL}|  ${YLW}'--> ${GRN}List ${YLW}$STORAGE_LIST${GRN} of storage content now ready!"
echo -e "${RSTCOL}|"

echo -e "${WHT}Checking the storage content for potentially interesting files..."
for file in "${INTRST[@]}"
do
	MATCHROW=$(grep -n ".$file" "$STORAGE_LIST"|sed 's/:.*$//g')
	if [[ ! -z "$MATCHROW" ]]
	then
		MATCH=0

		while [ "$MATCH" == 0 ]
		do
			PARENT_DIR=$(sed -n "$MATCHROW"p "$STORAGE_LIST" |grep "^storage")
			let "MATCHROW-=1"
			if [[ ! -z "$PARENT_DIR" ]]
			then
				echo "$PARENT_DIR" >> "$INTRST_LIST"
				MATCH=1
			fi
		done
	fi
	grep ".$file" "$STORAGE_LIST" >> "$INTRST_LIST"
done
if [ $(wc -m "$INTRST_LIST" |sed 's/ '"$INTRST_LIST"'//g') -gt 10 ]
then
	echo -e "${RSTCOL}|  ${YLW}'-->${GRN} Following interesting files found:"
	cat "$INTRST_LIST" |sed 's/^/\x1b[1;32m|\x1b[1;33m       /g'
fi
echo -e "${RSTCOL}|"

echo -e "${RSTCOL}|"
echo -e "'----------------------------${RED}[${YLW} D O N E ${RED}]${RSTCOL}----------------------------"
echo -e "${RSTCOL} "
