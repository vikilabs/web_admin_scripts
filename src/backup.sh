#!/bin/bash

# Backup website ( code and database )
#
#		Author	: Viki (a) Vignesh Natarajan 
#		Contact	: vikilabs.org
#		Licence : MIT

CURRENT_DIR=`pwd`

######################### GET CURRENT TIME STAMP #############
DAY=$(date '+%d')
MONTH=$(date '+%m')
YEAR=$(date '+%Y')
HOUR=$(date '+%H')
MINUTE=$(date '+%M')
TIME_STAMP="D${DAY}${MONTH}${YEAR}_T${HOUR}${MINUTE}"

######################## IMPORT CONFIGURATION ################
source ./config.sh
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }

####################### PRE VALIDATION        ###############
if [ "$WEBSITE_ROOT_DIR" = "$BACKUP_DIR" ]; then
    echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] WEBSITE_ROOT_DIR and BACKUP_DIR should be different" >> $LOG_FILE
    exit 1
fi

####################### CREATE BACKUP LABEL   ##############
BACKUP_LABEL="${DOMAIN}_${TIME_STAMP}"

echo
echo "  Website Root      : $WEBSITE_ROOT_DIR"
echo "  DB NAME           : $DB_NAME"
echo "  DB USER           : $DB_USERNAME"
echo "  DB PASSWORD       : xxxxxxxxx"
echo "  DB HOST       	  : $DB_HOST"
echo "  DB PORT       	  : $DB_PORT"
echo "  Backup Directory  : $BACKUP_DIR"
echo "  Backup Label      : $BACKUP_LABEL"
echo "  Backup File       : ${BACKUP_LABEL}.tar.gz"
echo 

#safely get full path of website root ( this method is use to handle directories like ~/ )
cd $WEBSITE_ROOT_DIR
WEBSITE_ROOT_DIR=`pwd`

####################### DB ACCESS CHECK ######################
table_count=$(mysql -u$DB_USERNAME -p$DB_PASSWORD -h $DB_HOST -P $DB_PORT $DB_NAME -e "SHOW TABLES;" | wc -l)

if [ $? -ne 0 ];then
        echo "[ ERROR ] [ ${LINENO} ] DB access error"
        exit 1
fi

########### CHECK IF WEBSITE CONTENT  IS AVAILABLE OR NOT  ##############
file_count=`ls ${WEBSITE_ROOT_DIR}/ | wc -l`
if [ $file_count -le 0 ];then
        echo "[ ERROR ] [ ${LINENO} ] website root directory is empty, nothing to backup"
        exit 1
fi


#remove any backup directory with same name
rm -rf "$BACKUP_DIR/$BACKUP_LABEL"

#create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_LABEL"
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }
mkdir -p "$BACKUP_DIR/$BACKUP_LABEL/code"
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }
mkdir -p "$BACKUP_DIR/$BACKUP_LABEL/db"
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }

#######################  export database to backup directory ##############
mysqldump -u$DB_USERNAME  -p$DB_PASSWORD $DB_NAME > "$BACKUP_DIR/$BACKUP_LABEL/db/database.sql"
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }

#######################  copy website content to backup directory #########
cp -arf $WEBSITE_ROOT_DIR/* $BACKUP_DIR/$BACKUP_LABEL/code/
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }

#######################  Optimize Backup ##################################

#Truncate Log Files
CMD="$CURRENT_DIR/support_scripts/clear_logs.sh"
if [ -f "$CMD" ]; then
    #Execute if file exist
    $CMD "$BACKUP_DIR/$BACKUP_LABEL/code/"
fi

#Clear Stale Files ( if any )
CMD="$CURRENT_DIR/support_scripts/clear_stale_files.sh"
if [ -f "$CMD" ]; then
    #Execute if file exist
    $CMD "$BACKUP_DIR/$BACKUP_LABEL/code/"
fi

###################### Generate Restore Config ############################

cp $CURRENT_DIR/config.sh $BACKUP_DIR/$BACKUP_LABEL/restore_config.sh
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }

#######################  create a tar.gz archive from backup ##############

cd $BACKUP_DIR
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }

tar -czvf "${BACKUP_LABEL}.tar.gz" $BACKUP_LABEL
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }

#######################  remove $BACKUP_LABEL directory ###################
rm -rf $BACKUP_LABEL
[ $? -ne 0 ] && { echo "[ $TIME_STAMP ] [ ERROR ] [ ${LINENO} ] " >> $LOG_FILE; exit 1; }

