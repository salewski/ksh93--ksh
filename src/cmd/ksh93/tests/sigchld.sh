########################################################################
#                                                                      #
#               This software is part of the ast package               #
#          Copyright (c) 1982-2012 AT&T Intellectual Property          #
#          Copyright (c) 2020-2024 Contributors to ksh 93u+m           #
#                      and is licensed under the                       #
#                 Eclipse Public License, Version 2.0                  #
#                                                                      #
#                A copy of the License is available at                 #
#      https://www.eclipse.org/org/documents/epl-2.0/EPL-2.0.html      #
#         (with md5 checksum 84283fa8859daf213bdda5a9f8d1be1d)         #
#                                                                      #
#                  David Korn <dgk@research.att.com>                   #
#                  Martijn Dekker <martijn@inlv.org>                   #
#            Johnothan King <johnothanking@protonmail.com>             #
#                                                                      #
########################################################################

. "${SHTESTS_COMMON:-${0%/*}/_common}"

float DELAY=${1:-0.2}
integer FOREGROUND=10 BACKGROUND=2

s=$($SHELL -c '
integer i foreground=0 background=0
float delay='$DELAY' d=0 s=0

set --errexit

trap "(( background++ ))" CHLD

(( d = delay ))
for ((i = 0; i < '$BACKGROUND'; i++))
do	sleep $d &
	(( d *= 4 ))
	(( s += d ))
done
for ((i = 0; i < '$FOREGROUND'; i++))
do	(( foreground++ ))
	sleep $delay
	(( s -= delay ))
	$SHELL -c : > /dev/null # foreground does not generate SIGCHLD
done
if	(( (s += delay) < 1 ))
then	(( s = 1 ))
fi
sleep $s
wait
print foreground=$foreground background=$background
') || err_exit "test loop failed"

eval $s

(( foreground == FOREGROUND )) || err_exit "expected '$FOREGROUND foreground' -- got '$foreground' (DELAY=$DELAY)"
(( background == BACKGROUND )) || err_exit "expected '$BACKGROUND background' -- got '$background' (DELAY=$DELAY)"

set --noerrexit

if	[[ ${.sh.version} == Version?*([[:upper:]])J* ]]
then

	jobmax=4
	got=$($SHELL -c '
		JOBMAX='$jobmax' JOBCOUNT=$(('$jobmax'*2))
		integer running=0 maxrunning=0
		trap "((running--))" CHLD
		for ((i=0; i<JOBCOUNT; i++))
		do	sleep 1 &
			if	((++running > maxrunning))
			then	((maxrunning=running))
			fi
		done
		wait
		print running=$running maxrunning=$maxrunning
	')
	exp='running=0 maxrunning='$jobmax
	[[ $got == $exp ]] || err_exit "SIGCHLD trap queueing failed -- expected '$exp', got '$got'"

	got=$($SHELL -c '
		typeset -A proc

		trap "
			print \${proc[\$!].name} \${proc[\$!].status} \$?
			unset proc[\$!]
		" CHLD

		{ sleep .3; print a; exit 1; } &
		proc[$!]=( name=a status=1 )

		{ sleep .2; print b; exit 2; } &
		proc[$!]=( name=b status=2 )

		{ sleep .1; print c; exit 3; } &
		proc[$!]=( name=c status=3 )

		while	(( ${#proc[@]} ))
		do	sleep -s
		done
	')
	exp='c\nc 3 3\nb\nb 2 2\na\na 1 1'
	[[ $got == $exp ]] || err_exit "SIGCHLD trap queueing failed -- expected $(printf %q "$exp"), got $(printf %q "$got")"

fi

{
got=$( ( sleep .1;print $'\n') | $SHELL -c 'function handler { : ;}
	trap handler CHLD; sleep .03 & IFS= read; print good')
} 2> /dev/null
[[ $got == good ]] || err_exit 'SIGCHLD handler affects read behavior'

set -- $(
	(
	$SHELL -xc $'
		trap \'wait $!; print $! $?\' CHLD
		{ sleep 0.01; exit 9; } &
		print $!
		sleep 0.05
	'
	) 2>/dev/null; print $?
)
if	(( $# != 4 ))
then	err_exit "CHLD trap failed -- expected 4 args, got $#"
elif	(( $4 != 0 ))
then	err_exit "CHLD trap failed -- exit code $4"
elif	(( $1 != $2 ))
then	err_exit "child PID mismatch -- got '$1' != '$2'"
elif	(( $3 != 9 ))
then	err_exit "child status mismatch -- expected '9', got '$3'"
fi

trap '' CHLD
integer d
for ((d=0; d < 2000; d++))
do      if      print foo | grep bar
	then    break
	fi
done
(( d==2000 )) ||  err_exit "trap '' CHLD causes side effects d=$d"
trap - CHLD

if((!SHOPT_SCRIPTONLY));then
x=$($SHELL 2> /dev/null -ic '/dev/null/notfound; sleep .05 & sleep .1;jobs')
[[ $x == *Done* ]] || err_exit 'SIGCHLD blocked after notfound'
x=$($SHELL 2> /dev/null  -ic 'kill -0 12345678901234567876; sleep .05 & sleep .1;jobs')
[[ $x == *Done* ]] || err_exit 'SIGCHLD blocked after error message'
fi # !SHOPT_SCRIPTONLY

print 'set -o monitor;sleep .05 & sleep .1;jobs' > $tmp/foobar
chmod +x $tmp/foobar
x=$($SHELL  -c "echo | $tmp/foobar")
[[ $x == *Done* ]] || err_exit 'SIGCHLD blocked for script at end of pipeline'

# ======
exit $((Errors<125?Errors:125))
