#!/bin/bash

# Global Variables

product_name="Talos Backup and Compression Tool"
process_name="tarbackup"
version="2.0.1"
bundle_id="com.talosfleet.${process_name}"
hostname=$(hostname -s)
basename=$(basename $0)
pid="$$"
 
# Logging Functions
logverb() {
	message="${1}"
	severity="${2:-5}"
	case "${severity}" in
	 1) level="Error" ;;
	 2) level="Warning" ;;
	 3) level="Notice" ;;
	 4) level="Info" ;;
	 5) level="Debug" ;;
	esac
	[[ ${verbosity} -ge ${severity} ]] && echo "${level}: ${message}"
	exec 3>>"${logfile}"
	[[ ${verbosity} -ge ${severity} ]] && echo "$(date -j '+%b %d %H:%M:%S %Z') ${hostname} ${process_name}[${pid}]: <${level}> ${message}" >&3
	exec 3>&-
}
logpipe() {
  while read line
  do
    logverb "${line}" "${severity}"
  done
}

# Closes out logging and exits the script with the supplied error code
goodbye() {
  exitcode="${1:-255}"
  case "${exitcode}" in
    0) exitdesc="Success" ;;
    2) exitdesc="Required folder missing or not writable" ;;
    *) exitdesc="Undefined Error" ;;
  esac
	[[ ${exitcode} == 0 ]] && exitlvl=5 || exitlvl=1
	logverb "Exiting with exit code ${exitcode}: ${exitdesc}" ${exitlvl}
  exec 2>&-
  exit "${exitcode}"
}
 
# Option Processing
verbosity=4 # Default
logfile="/var/log/talos.log" # Default
while getopts 'v:f:' option
do
  case $option in
    'v') verbosity="${OPTARG}" ;;
    'f') logfile="${OPTARG}" ;;
  esac
done
shift $(( OPTIND - 1 ))

# Logfile Testing
if [[ ! -f "${logfile}" ]]
then
	logdir=$(/usr/bin/dirname "${logfile}")
	if [[ ! -d "${logdir}" ]]
	then
		mkdir -p "${logdir}"
	fi
	touch "${logfile}"
fi
if [[ ! -w "${logfile}" ]]
then
	echo "Warning: Log file ${logfile} is not writable by $(whoami). The log will not be populated." 1>&2
	logfile="/dev/null"
fi

# Pass StdErr to logpipe
exec 2> >(logpipe 2) 

# Start Your Script Here

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
  goodbye 2
fi
 
# Verify sourcepath is readable
logverb "Verifying sourcepath is readable" 5
if [ -r "${sourcepath}" ]
then
  logverb "${sourcepath} is readable" 5
else
  logverb "Error: sourcepath is not readable. Exit." 1
  goodbye 2
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
    goodbye 2
  fi
fi
 
# Verify backuppath is writeable
logverb "Verifying backuppath is writeable" 5
if [ -w "${backuppath}" ]
then
  logverb "${backuppath} is writable" 5
else
  logverb "Error: backuppath is not writeable. Exit." 1
  goodbye 2
fi
 
# Warn if backuppath is temporary
if [ "${backuppath}" == "/tmp" ]
then
  logverb "Warning: backuppath is ${backuppath}. Your backup may become lost." 2
fi
 
# Set backup name
backuptitle=$(echo "${sourcepath}" | sed 's/\//\ /g' | awk '{print $NF}')
logverb "backuptitle is ${backuptitle}" 5
backupname=$(echo "${backuptitle}_${timestamp}.tar.gz")
logverb "backupname is ${backupname}" 5
 
# Run the backup
logverb "Running tar -cvzpf ${backuppath}/${backupname} ${sourcepath}" 5
tar -cvzpf "${backuppath}/${backupname}" "${sourcepath}" 2>&1 | logpipe 4
result=${PIPESTATUS[0]}
[[ "${result}" == 0 ]] && logverb "${backupname} was backed up succesfully to ${backuppath}" 3 || logverb "Error: Backup of ${backuptitle} failed" 1
 
# Clean up old backups
if [[ "${daystokeep}" != 0 ]]
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
