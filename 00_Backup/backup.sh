# Programm: jedox_backup.sh
# Autor : Philipp Frenzel <frp@informatec.com>
#
# Inhalt : 
#   1. Jedox stoppen
#	2. Sicherung der Jedoxdaten (/mnt/data/Jedox/Data) und Anlegen einer Logfile als Tagessicherung / Vollsicherung am Montag und dann inkrementelle Sicherung am Di, Mi, Do, Fr.
#	3. Jedox starten
#	4. Aufraeumen: Logfiles, älter als 90 Tage, werden gelöscht/Backups älter 14 Tage werden gelöscht

# Datum : 23./29.10.2015
# Aenderung: 05.02.2016: Aufraeumem erweitert - Backups aelter 14 Tage werden gelöscht; Aufraeumen nur Montags
#	15.02.2016: .archived Dateien werden Montags geloescht;
#	22.02.2016: Aenderung der Eigentumerrechte, einmal Eigentuemer root für das Backup und dann wieder zurueckgeben an jedoxweb
#	10.10.2016: log-Aenderungen eingeführt, eigenes log für den olap Server unter Data.

# Funktionen:
sende_mail(){
echo "$2" | mailx -S smtp=server:port -s "$1" -v frp@informatec.com
}

# Variablen
DATUM=$(date +"%Y%m%d")
INSTALLPFAD=/mnt/data/Jedox
OBJECTSPFAD=/mnt/data/Jedox/Data
SOURCE=""
BACKUP_DIR=${OBJECTSPFAD}/../../Backup
LOGFILE=${OBJECTSPFAD}/../../Backup/Logdateien/Backuplog_${HOSTNAME}_${DATUM}.log
WOCHENTAG=$(date +"%u")
RC=0

#check User
if [ `id -un` != "root" ]
then
echo "User ungueltig, benoetigt wird root"
sende_mail "Probleme beim Backup auf der $HOST" "User ungueltig, benoetigt wird root"
exit 1
fi

echo $(date +"%H:%M:%S")": START - Jedox stoppen ----------------------------------------" >> ${LOGFILE}
sudo ${INSTALLPFAD}/jedox-suite.sh stop >> ${LOGFILE}
wait $(pgrep palo)

echo "Backup ${HOSTNAME} vom $(date +"%d.%m.%Y-%H:%M")----------------------------------------" >> ${LOGFILE}

cd ${OBJECTSPFAD}
RC=$?
#Prüfen, ob Ordner da ist - wenn dann ist $? gleich 0
if [[ $RC -ge 1 ]];
then
echo "Pfad nicht gefunden. Backup nicht ausgefuehrt!" >> ${LOGFILE}
sende_mail "Probleme beim Backup auf der ${HOSTNAME}" "Bitte die Logdatei des Backups ueberpruefen: ${LOGFILE}"
#echo "Bitte die Logdatei des Backups ueberpruefen: ${LOGFILE}" | mailx -S smtp=smtprelay1.s-v.loc:25 -s "Probleme beim Backup auf der ${HOSTNAME}" -v $MAILEMPFAENGER
exit 8
fi

# Backup
echo $(date +"%H:%M:%S")": Beginn der Sicherung" >> ${LOGFILE}

#root die Eigentuemerrechte geben, damit er das Backup auch komplett ausfuehren kann
sudo chown -R root /mnt/data/Jedox/Data/

#gucken, ob Montag ist
if [[ ${WOCHENTAG} == 1 ]]; then
FILENAME=${BACKUP_DIR}/Backup_${HOSTNAME}_${DATUM}.${WOCHENTAG}
echo "Vollbackup: ${FILENAME}.tar" >> ${LOGFILE}

#snapshot Datei wird gelöscht
rm ${BACKUP_DIR}/usr.snar
tar -vcz --file=${FILENAME}.tar.gz --listed-incremental=${BACKUP_DIR}/usr.snar ${SOURCE} >> ${LOGFILE}

elif [[ ${WOCHENTAG} -ge 2 && ${WOCHENTAG} -le 5 ]]; then
SDATUM=$(date -d "last Monday" +"%Y%m%d")
FILENAME=${BACKUP_DIR}/Backup_${HOSTNAME}_${SDATUM}.${WOCHENTAG}
echo "inkrementelles Backup: ${FILENAME}.tar" >> ${LOGFILE}

tar -vcz --file=${FILENAME}.tar.gz --listed-incremental=${BACKUP_DIR}/usr.snar ${SOURCE} >> ${LOGFILE}
#tar -vcf ${BACKUP_DIR}/Backup_${HOSTNAME}_${DATUM}.tar ${SOURCE} >> ${LOGFILE}
fi

RC=$?
#Prüfen ob Kompression ohne Fehler
if [[ $RC -ge 1 ]];
then
rm ${FILENAME}.tar
echo $(date +"%H:%M:%S")": Tar nicht korrekt erstellt. Backup von ${HOSTNAME} wird nicht ausgefuehrt!" >> ${LOGFILE}
sende_mail "Probleme beim Backup auf der ${HOSTNAME}" "Bitte die Logdatei des Backups ueberpruefen: ${LOGFILE}"
exit 8
else
echo "$(date +"%H:%M:%S"): tar und compress erfolgreich." >> ${LOGFILE}
# echo "$(date +"%H:%M:%S"): TAR erfolgreich. Beginn Compress" >> ${LOGFILE}
# gzip ${FILENAME}.tar
# RC=$?
# #Prüfen ob Kompression ohne Fehler
# if [ $RC -ge 1 ];
# then
# rm ${FILENAME}.tar.gz
# echo "RC: $RC bei Compress " >> ${LOGFILE}
# echo $(date +"%H:%M:%S")": Compress nicht erfolgreich. Backup ueberpruefen!" >> ${LOGFILE}
# sende_mail "Probleme beim Backup auf der ${HOSTNAME}" "Bitte die Logdatei des Backups ueberpruefen: ${LOGFILE}"
#
# else
echo $(date +"%H:%M:%S")": Backup von ${HOSTNAME} wurde korrekt ausgefuehrt!" >> ${LOGFILE}
#fi
fi

#	zum unterbrechen
#	read -p "Press [Enter] key to delete files..."

# Nachträgliche Aufräumarbeiten; immer Montags
if [[ ${WOCHENTAG} == 1 ]]; then
echo $(date +"%H:%M:%S") "Aufraeumen - folgende Dateien werden geloescht:" >> ${LOGFILE}
#Logfiles, älter 90 Tage löschen
find /mnt/data/Backup/Logdateien/ -type f -mtime +91 -exec ls {} \; >> ${LOGFILE}
find /mnt/data/Backup/Logdateien/ -type f -mtime +91 -delete 2>> ${LOGFILE}
#Sicherungsdateien, älter 14 Tage löschen
find /mnt/data/Backup/Backup_lxkad* -type f -mtime +14 -exec ls {} \; >> ${LOGFILE}
find /mnt/data/Backup/Backup_lxkad* -type f -mtime +14 -delete 2>> ${LOGFILE}
#.archived-Dateien löschen
find /mnt/data/Jedox/Data/ -name '*.archived' -type f -exec ls {} \; >> ${LOGFILE}
find /mnt/data/Jedox/Data/ -name '*.archived' -type f -delete 2>> ${LOGFILE}
fi

#	zum unterbrechen
#	read -p "Press [Enter] key to start Jedox..."

#jedoxweb die Eigentuemerrechte zurueckgeben,
sudo chown -R jedoxweb /mnt/data/Jedox/Data/

echo $(date +"%H:%M:%S")": Jedox starten ----------------------------------------" >> ${LOGFILE}
#sudo ${INSTALLPFAD}/jedox-suite.sh start >> ${LOGFILE}
sudo ${INSTALLPFAD}/jedox-suite.sh start >> ${INSTALLPFAD}/log/olap_server.log
# eine Schleife, die 300 Sekunden lang prüft, ob die Dienste gestartet wurden
z=(0);
while [[ $z -lt 300 ]];
do
# Abfrage, ob die Jedox Dienste gestartet wurden
if pgrep "palo" && pgrep "core.bin" && pgrep "java" && pgrep -U jedoxweb "httpd";
then
echo $(date +"%H:%M:%S") "Alle Prozesse laufen - Jedox ordnungsgemaess gestartet!" >> ${LOGFILE}
break;
fi
sleep 30; z=`expr $z + 30`;
done;

# Prüfung ob alle Dienste gestartet sind, falls nicht eine Benachrichtigung...
if ! pgrep "palo" || ! pgrep "core.bin" || ! pgrep "java" || ! pgrep -U jedoxweb "httpd";
then sende_mail "Probleme beim Backup auf der ${HOSTNAME}" "Jedox wurde nicht ordentlich gestartet. Bitte pruefen."
fi

echo $(date +"%H:%M:%S") "Backup ENDE!" >> ${LOGFILE}

exit $RC
