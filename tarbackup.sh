#!/bin/bash
#####################################################################
# SCRIPT: tarbackup.sh
#
# AUTHORS: Sean Hansell
#
# VERSION 1.1 (10/17/2014)
# Information about this script can be found in the JWT IT Library:
# http://itlib.na.corp.jwt.com/services:scripting:tarbackup.sh
#
# USAGE: 
# tarbackup.sh [-v] verbosity [-l] /pathto/logfile [sourcepath] [backuppath] [daystokeep]
#####################################################################
 
# Logging Functions
logverb() {
  severity="${2:-5}"
  [[ "${verbosity}" -ge "${severity}" ]] && echo "$(date) (${severity}): ${1}"
  exec 3>>"${logfile}"
  [[ "${verbosity}" -ge "${severity}" ]] && echo "$(date) (${severity}): ${1}" >&3
  exec 3>&-
}
logpipe() {
  severity="${1:-5}"
  while read line
  do
    [[ "${verbosity}" -ge "${severity}" ]] && echo "$(date) (${severity}): ${line}"
    exec 3>>"${logfile}"
    [[ "${verbosity}" -ge "${severity}" ]] && echo "$(date) (${severity}): ${line}" >&3
    exec 3>&-
  done
} 

# Closes out logging and exits the script with the supplied error code
goodbye() {
  exitcode = "${1:-255}"
  logverb "exit code is ${exitcode}" 5
  logverb "----- End ${0} -----" 3
  exec 2>&-
  exit "${exitcode}"
}
 
# Option Processing
verbosity=5 # Default
logfile="/dev/null" # Default
while getopts 'v:l:' option
do
  case $option in
    'v') verbosity="${OPTARG}" ;;
    'l') logfile="${OPTARG}" ;;
  esac
done
 
# Welcome Message
logverb "----- ${0} ${*} -----" 3
 
# Pipe all STDERR through logpipe() level 1
exec 2> >(logpipe 1) 
 
# Shift options out so positional parameters are in the correct places
shift $(( OPTIND - 1 ))
 
# Logfile Testing
[[ -f "${logfile}" ]] || touch "${logfile}"
[[ -w "${logfile}" ]] || echo "Error: logfile ( ${logfile} ) is not writable." 1>&2
 
# Variables
protosourcepath="${1}"
logverb "Variable protosourcepath is ${protosourcepath}" 5
protobackuppath="${2:-/tmp/}"
logverb "Variable protobackuppath is ${protobackuppath}" 5
daystokeep="${3:-0}"
timestamp="$(date +%Y-%m-%d-%H%M)"
logverb "Variable timestamp is ${timestamp}" 5
 
# Hack off any trailing slashes
logverb "Hacking off any trailing slashes" 5
sourcepath=$(echo "${protosourcepath}" | sed 's,/$,,')
logverb "Variable sourcepath is ${sourcepath}" 5
backuppath=$(echo "${protobackuppath}" | sed 's,/$,,')
logverb "Variable backuppath is ${backuppath}" 5
 
# Verify sourcepath exists
logverb "Verifying sourcepath exists" 5
if [ -d "${sourcepath}" ]
then
  logverb "${sourcepath} exists" 5
else
  logverb "Error: sourcepath variable is empty. Exit." 1
  goodbye 1
fi
 
# Verify sourcepath is readable
logverb "Verifying sourcepath is readable" 5
if [ -r "${sourcepath}" ]
then
  logverb "${sourcepath} is readable" 5
else
  logverb "Error: sourcepath is not readable. Exit." 1
  goodbye 1
fi
 
# Verify backuppath exists
logverb "Verifying backuppath exists" 5
if [ -d "${backuppath}" ]
then
  logverb "${backuppath} exists" 5
else
  logverb "backuppath does not exist. Creating ${backuppath}." 4
  mkdir -p "${backuppath}" && logverb "${backuppath} created succesfully" 4
  logverb "Reverifying backuppath" 5
  if [ -d "${backuppath}" ]
  then
    logverb "${backuppath} exists" 5
  else
    logverb "Error: backuppath could not be created. Exit." 1
    goodbye 1
  fi
fi
 
# Verify backuppath is writeable
logverb "Verifying backuppath is writeable" 5
if [ -w "${backuppath}" ]
then
  logverb "${backuppath} is writable" 5
else
  logverb "Error: backuppath is not writeable. Exit." 1
  goodbye 1
fi
 
# Warn if backuppath is temporary
if [ "${backuppath}" == "/tmp" ]
then
  logverb "Warning: backuppath is ${backuppath}. Your backup may become lost." 2
fi
 
# Set backup name
backuptitle=$(echo "${sourcepath}" | sed 's/\//\ /g' | awk '{ print $NF }')
logverb "backuptitle is ${backuptitle}" 5
backupname=$(echo "${backuptitle}_${timestamp}.tar.gz")
logverb "backupname is ${backupname}" 5
 
# Run the backup
logverb "Running tar -cvzpf ${backuppath}/${backupname} ${sourcepath}" 5
tar -cvzpf "${backuppath}/${backupname}" "${sourcepath}" 2>&1 | logpipe 4
result=`echo "${PIPESTATUS[0]}"`
[[ "${result}" == 0 ]] && logverb "${backupname} was backed up succesfully to ${backuppath}" 3 || logverb "Error: Backup of ${backuptitle} failed" 1
 
# Clean up old backups
if [ "${daystokeep}" != 0 ]
then
  logverb "Cleaning up old backups" 5
  deletelist=$(find "${backuppath}" -maxdepth 1 -mindepth 1 ! -mtime -"${daystokeep}")
  if [ "${deletelist}" != "" ]
  then
    echo "${deletelist}" | while read deletefile
    do
      rm "${deletefile}" && logverb "File: ${deletefile} was deleted" 3 || logverb "File: ${deletefile} could not be deleted" 2
    done
  else
    logverb "No files to be deleted" 3
  fi
else
  logverb "Cleanup of old backups is disabled" 5
fi
 
# Goodbye
goodbye 0
