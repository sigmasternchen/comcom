#!/bin/sh
#
name="\"comcom\" - AVR Shellscript for JTAG"
# Author: Buchberger Florian
version="2.2.3.5"
# Date: 01. 06. 2012
# Description: 
#   Shellscript to convert C++ and assambler files to hexadecimal files for µ-processors over a JTAG ICE emulator.
#
# Changelog:
#	2.2.3.5:	better source code, device type parmeter is avrdude device partno, if not supported by this script
#	2.2.3.4:	device type parameter (atmega8, 16, 32, 64, 128, attiny10, 13, 15) 
#	2.2.3.3:	better source code
#	2.2.3.2:	better cl help
#	2.2.3.1:	cl help updated
#	2.2.3:		multible c files
#	2.2.2:		liunx installer
#	2.2.1:		os cl option
#	2.2: 	  	mac version
# 	2.1: 	  	cl options
#	2.0:	  	hex input
#	1.9:	  	asm input
#	1.4:	  	better error messages
#	1.0:	  	first version		
#
#
# exit codes:
# 0  : no error
# 1  : argument error
# 2  : compiling error
# 3  : conversion error
# 4  : removing error
# 5  : comunitating error
# 6x : programs not found
#    : 1  : avr-gcc
#    : 2  : avr-asm
#    : 3  : objcopy
#    : 4  : rm
#    : 5  : cp
#    : 6  : avrdude
# 7  : os error

################################
# variables
################################

# constant definitions

defInputC=""
defInputAsm=$defInputC
defInputHex=""
defTmpObj=$defInputC.$$.obj
defOutputHex=$defInputC.hex
defDev="/dev/ttyUSB0"
defAtType="atmega16"

# basic variables (parameter)
inputC=$defInputC
inputAsm=$defInputAsm
inputHex=$defInputHex
tmpObj=$defTmpObj
outputHex=$defOutputHex
dev=$defDev
atType=$defAtType

# type selection variables
usingC=0
usingAsm=0;
usingHex=0

# C++ compiler & arguments
compiler="/usr/bin/avr-g++"
compilerArgsT="-g -Os -Wall -mcall-prologues -mmcu="
compilerO="-o"

# if compiler isn't found, then get path
if test ! -f $compiler ;then
	compiler=`which avr-g++`
fi 

# assambler & arguments
asm="/usr/bin/avr-as"
asmO="-o"
asmT="-mmcu"

# if compiler isn't found, then get path
if test ! -f $asm ;then
	asm=`which avr-as`
fi 

# obj2hex program & arguments
objcopys="/usr/bin/avr-objcopy"
objcopyArgs="-R .eeprom -O ihex"

# if program isn't found, then get path
if test ! -f $objcopys ;then
	objcopys=`which avr-objcopy`
fi 

# remove
copy="/bin/cp"

# if program isn't found, then get path
if test ! -f $copy ;then
	copy=`which cp`
fi 

# copy
remove="/bin/rm"

# if program isn't found, then get path
if test ! -f $remove ;then
	remove=`which rm`
fi 

# programmer (here jtag1 -> JTAG ICE)
prog="jtag1"

# avrdude & arguments
dude="/usr/bin/avrdude"
dudeT="-p"
dudeD="-P"
dudeP="-c"
dudeHex="-U flash:w:"

# if program isn't found, then get path
if test ! -f $dude ;then
	dude=`which avrdude`
fi 

# temporary variables & time variables

eTmp=0

# start time in s & ns
sTimeN=`date +%N`
sTimeS=`date +%s`

# end time in s & ns (not defined yet)
eTimeN=0;
eTimeS=0;

# deference time (eTime - sTime)
dTimeN=0;
dTimeS=0;

# user specified os
uos=0;

# only output file
outputOnly=0

################################
# texts
################################

error="Error occurred!"
ec="Exiting with error code"
helptext="
$name
Version $version 
by Buchberger Florian

Usage: $0 [options]

Options:
--output [file] or -o [file]
	: filename for compiled file
--c-input [files] or -ic [files]
	: filenames for a c or c++ coded source file
--asm-input [file] or -ia [file]
	: filename for a assambler coded source file
--hex-input [file] or -ih [file]
	: filename for a compliled hex source file
--temp-file [file] or -tf [file]
	: filename for a temporary output file
--os [type]
	: specify operating system 
	: possibilitys for [type]:
	: : macosx
	: : linux
--device [file] or -d [file]
	: filename of device (default: /dev/ttyUSB0)
--type [type] or -t [type]
	: device type (default: atmega16)
--help or -h
	: displays this help text"


################################
# installation function
################################

install() {
	case $1 in
		"linux")
			echo "This skript needs root rights for installing necessary programs."
			# download programs via apt-get
			sudo apt-get install gcc-avr binutils-avr avrdude 
			;;
		"macosx")
			echo "Mac installer not finished yet."
			# todo
			;;
		*)
			return 1
	esac
	return 0
}

################################
# interpret arguments
################################

# which other parameter is needed (out, asm, hex, tmp, dev, type, os, c or empty ())
needString=""

# parameter error
parameterE=""

# should the cl help text be displeyed?
useHelp=0

# should the installer be started?
install=0

# is next parameter a option or a file/type? (0 -> option, 1 -> file/type)
next=0

# for ervery parameter do
for i in $* ;do

	case $needString in
	
		# outfile
		"out") 
			outputHex=$i 
			needString="" 
			;;
		
		# infile is an asambler file
		"asm")
			inputAsm=$i
			usingAsm=1
			needString="" 
			;;
			
		# infile is a hex file
		"hex")
			inputHex=$i
			usingHex=1
			needString=""
			;;
			
		# tmp file
		"tmp") 
			tmpObj=$i 
			needString="" 
			;;
			
		# specified device (default: /dev/ttyUSB0)
		"dev") 
			dev=$i 
			needString="" 
			;;
			
		# controller type (default: atmega16)
		"type") 
			atType=$i 
			needString="" 
			;;
			
		# operating system
		"os")
			uos=$i
			needString="" 
			;;
			
		# infile(s) is/are c files
		"c")
			# if file exists then ad file to list of c files
			if test -f $i ;then
				inputC="$inputC $i"
				usingC=`echo "scale=0; ($usingC + 1)" | bc`
			
			# else no other strings will be used for this option
			# this parameter $i is also used for interpreting options
			else
				needString=""
				next=1
			fi
			;;
			
		# if no string is needed ($needString = "") this parameter is used for interpreting options
		*)
			next=1
			;;
	esac
	
	# if parameter is used for interprting options
	if test $next = 1 ;then
		case $i in
			"-o" | "--output")
				needString="out" ;;
			"-ic" | "--c-input")
				needString="c" ;;
			"-ia" | "--asm-input")
				needString="asm" ;;
			"-tf" | "--temp-file")
				needString="tmp" ;;
			"-d" | "--device")
				needString="dev" ;;
			"-t" | "--type")
				needString="type" ;;
			"-h" | "--help")
				useHelp=1 ;;
			"--os")
				needString="os" ;;
			"-ih" | "--hex-input")
				needString="hex" ;;
			"-oo" | "--output-only")
				outputOnly=1 ;;
			"--install")
				install=1 ;;
			*)
				parameterE="Invalid Argument $i. \nUse '--help' to get a list of parameters." ;;
		esac
		next=0
	fi
done

# if number of args = 0 display error
if test $# = 0 ;then
	echo $error
	echo "$ec 1..."
	echo "No arguments specified!"
	echo "Use '--help' to get a list of parameters."
	exit 1
fi

# if help text is used ... ehm yeah...
if test $useHelp = 1 ;then
	echo "$helptext"
	exit 0
fi

# if install should be startet
if test $install = 1 ;then
	
	# if no operating system is specified then abort
	if test $uos = 0 ;then
		echo $error
		echo "$ec 7..."
		echo "No Operating System specified!"
		exit 7
	fi
	
	# start install function
	install $uos
	
	# if function return error 1 then abort
	if test $? = 1 ;then
		echo $error
		echo "$ec 7..."
		echo "Operating System not supported!"
		exit 7	
	fi
	exit 0
fi

tmp=0;

tmp=`echo "scale=0; ($usingAsm + $usingC + $usingHex)" | bc`

# number of different types of input files should be exact 1
if test $tmp != 1 ;then
	parameterE="Invalid number of input files!"
fi

# if another parameter is needed 
# and needed parameter is not c file
# and there is at least 1 c file
if test \( "$needString" != "" \) -a \( "$needString" != "c" \) -a \( $usingC = 0 \) ;then
	parameterE="Expression missing!"
fi

# if error is set display error message
if test "$parameterE" != "" ;then
	echo $error
	echo "$ec 1..."
	echo $parameterE
	exit 1
fi

# if no tmp file is specified a new file name will be set
if test "$tmpObj" = "$defTmpObj" ;then
	tmpObj=$$.obj
fi

# if no output file name is specified the file name will be set
if test "$outputHex" = "$defOutputHex" ;then
	input=""
	if test $usingC = 1 ;then
		input=$inputC
	fi
	if test $usingHex = 1 ;then
		input=$inputHex
	fi
	if test $usingAsm = 1 ;then
		input=$inputAsm
	fi
	fname=`echo $input | awk '{print $1}'`
	outputHex=$fname.hex
fi

################################
# check operating system
################################

# is the operation system Linux?
oos=`uname -a | awk "/Linux/{print $1}"`

os=0

# if operating system is linux
if test $oos != "" ;then
	os=1
fi

# if --os parameter is specified
if test $uos != 0 ;then
	case $uos in 
		"macosx")
			def="/dev/cu.usbserial-000012FD"
			os=1 
			;;
		"linux")
			os=1
			;;
		*)
			os=0 ;;
	esac
fi

# if still os unknown
if test $os = 0 ;then
	echo $error
	echo "$ec 7..."
	echo "Unknown Operating System!"
	echo "Please use --help to get advice."
	exit 7
fi

################################
# testing program installation
################################
# testing all programs if they exist

if test ! -f $compiler ;then
	echo $error
	echo "$ec 61..."
	echo "Program not found."
	echo "Please install avr-gcc or start with parameter \"--install\"."
	exit 61
fi
if test ! -f $asm ;then
	echo $error
	echo "$ec 62..."
	echo "Program not found."
	echo "Please install avr-as or start with parameter \"--install\"."
	exit 62
fi
if test ! -f $objcopys ;then
	echo $error
	echo "$ec 63..."
	echo "Program not found."
	echo "Please install avr-objcopy or start with parameter \"--install\"."
	exit 63
fi
if test ! -f $remove ;then
	echo $error
	echo "$ec 64..."
	echo "Program not found."
	echo "Please install rm or start with parameter \"--install\"."
	exit 64
fi
if test ! -f $copy ;then
	echo $error
	echo "$ec 65..."
	echo "Program not found."
	echo "Please install cp or start with parameter \"--install\"."
	exit 65
fi
if test ! -f $dude ;then
	echo $error
	echo "$ec 66..."
	echo "Program not found."
	echo "Please install avrdude or start with parameter \"--install\"."
	exit 66
fi

################################
# program
################################

# if not hex input
if test $usingHex = 0 ;then

	# if c, compile c files to $tmpObj
	if test $usingC = 1 ;then
		$compiler $compilerArgsT$compilerArgsTp$atType $inputC $compilerO $tmpObj 
	fi

	# if asm, compile asm files to $tmpObj
	if test $usingAsm = 1 ;then
		$asm $asmO $tmpObj $asmT$atType $inputAsm
	fi

	eTmp=$?

	# if compiler returns error, display error and abort
	if test ! \( $eTmp = 0 \) ;then
		echo $error
		if test $usingC = 1 ;then
			echo "$compiler returned $eTmp"
		else 
			echo "$asm returned $eTmp"
		fi
		echo "Aborting..."
		echo "$ec 2..."
		exit 2
	fi

	# if tmpObj not exists
	if test ! \( -f $tmpObj \) ;then 
		echo $error 
		echo "Unable to create temporary object file!"
		echo "$ec 2..."
		exit 2
	fi

	# copy tmpObj to $ouputhex
	$objcopys $objcopyArgs $tmpObj $outputHex

	eTmp=$?

	# if objcopy returns error, display error and abort
	if test ! \( $eTmp = 0 \) ;then
		echo $error
		echo "$objcopys returned $eTmp"
		echo "Aborting..."
		echo "$ec 3..."
		exit 3
	fi

	# if $outputHex not exists
	if test ! -f $outputHex ;then 
		echo $error 
		echo "Unable to create .hex - file!"
		echo "$ec 3..."
		exit 3
	fi

	# remove tmp file
	$remove $tmpObj

	eTmp=$?

	# if rm returns an error, display error and abort
	if test ! \( $eTmp = 0 \) ;then
		echo $error
		echo "$remove returned $eTmp"
		echo "Aborting..."
		echo "$ec 4..."
	fi

	# if tmpObj still exists, display error
	if test -f $tmpObj ;then
		echo $error
		echo "Unable to delete temporary object file!"
		echo "$ec 4..."
		exit 4
	fi

else
	# if hex input file does not exist
	if test ! \( -f $inputHex \) ;then
		echo $error
		echo "Input file not found!"
		echo "$ec 1..."
		exit 1
	fi

	# copy input hex to output hex
	$copy $inputHex $outputHex

fi

# if output only parameter isn't set
if test $outputOnly = 0 ;then

	# convert name into partno parameter for avrdude
	case $atType in
		"atmega8") dAtType="m8" ;;
		"atmega16") dAtType="m16" ;;
		"atmega32") dAtType="m32" ;;
		"atmega64") dAtType="m64" ;;
		"atmega128") dAtType="m128" ;;
		
		"attiny10") dAtType="t10" ;;
		"attiny13") dAtType="t13" ;;
		"attiny15") dAtType="t15" ;;
		
		# if name isn't supported, partno parmeter is type argument
		*) dAtType=$atType ;;
	esac

	# execute avrdude
	$dude $dudeT $dAtType $dudeD $dev $dudeP $prog $dudeHex$outputHex 

	eTmp=$?

	# if avrdude retruns an error, display error and abort
	if test ! \( $eTmp = 0 \) ;then
		echo $error
		echo "$dude returned $eTmp"
		echo "Aborting..."
		echo "Unable to send hex file to $atType"
		echo "$ec 5..."
		exit 5
	fi
fi

# set end time
eTimeN=`date +%N`
eTimeS=`date +%s`

# calculate time difference
dTimeN=`echo "scale=0; ($eTimeN - $sTimeN) / 1000000" | bc`
dTimeS=`echo "scale=0; ($eTimeS - $sTimeS)" | bc`

################################
# summary
################################

echo "\n"

echo "Summary:"
if test $usingC ;then
	echo " Source(s): $inputC"
fi
if test $usingAsm ;then
	echo "Source(s): $inputAsm"
fi
echo " Hex-File: $outputHex"
echo " Device: $dev"
echo " Programmer: $prog"
echo " Compiler: $compiler"
echo " Hex-File-Coder: $objcopys"
echo " Driver: $dude"
echo " Time: $dTimeS s $dTimeN ms"
echo ""

echo "Writing successfully!"


exit 0
