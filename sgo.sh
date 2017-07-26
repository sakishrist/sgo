
__SGO_PARSE_RULE () {
	local mode rule elem al main var expr
	expr="$@"
	expr="${expr/$'\n'/ }";
	local IFS=$' \t\n'
	for elem in $expr; do
		var=${elem%%=*}
		rule=${elem#*=}

		if [[ ${rule:0:1} == '[' && ${rule: -1} == ']' ]]; then
			if [[ $rule =~ '|' ]]; then
				mode=2
			else
				mode=1
			fi
			rule=${rule%%']'}
			rule=${rule##'['}
		elif [[ ${rule:0:1} == '{' && ${rule: -1} == '}' ]]; then
			rule=${rule%%'}'}
			rule=${rule##'{'}
			mode=3
		elif [[ ${rule:0:2} == '![' && ${rule: -1} == ']' ]]; then
			rule=${rule%%']'}
			rule=${rule##'['}
			mode=4
		elif [[ ${rule:0:2} == '!{' && ${rule: -1} == '}' ]]; then
			rule=${rule%%'}'}
			rule=${rule##'{'}
			mode=5
		else
			echo "syntax error: Rule '$rule' is not enclosed in [...] or {...}"
			return 1
		fi

		for opt in ${rule//|/ }; do
			main=${opt%%<*}
			al=${opt#*<}; al=${al%>}

			if [[ -z $main ]]; then
				echo "syntax error: empty opt"
				return 1
			fi

			VARS["$main"]="$var"
			MODES["$main"]="$mode"
			REAL_OPTS["$main"]="$main"

			if [[ -n $al ]]; then
				VARS["$al"]="$var"
				MODES["$al"]="$mode"
				REAL_OPTS["$al"]="$main"
			fi
		done
	done
}

__SGO_HANDLE () {
	local opt="$1"
	local var="$2"

	if [[ ${MODES[$opt]} == 1 ]]; then # Mode: increment VAR
		eval "((${VARS[$opt]}++))"
	elif [[ ${MODES[$opt]} == 2 ]]; then # Mode: assign option to VAR
		eval "${VARS[$opt]}=$opt"
	elif [[ ${MODES[$opt]} == 3 ]]; then # Mode: assign value to VAR
		if [[ ${BASH_VERSINFO[0]} -lt 4 || ( ${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -lt 3 ) ]]; then
			var="${var//\"/\"}"
		else
			var="${var//\"/\\\"}"
		fi
		eval "${VARS[$opt]}=\"$var\""
	fi
	#eval "echo ${VARS[$opt]}=\"\$${VARS[$opt]}\""
}

sgoInit () {
	__SGO_RULE="$@"
}

__SGO_DEBUG () {
	true '#####################'
	true '#       SGO         #'
	true '#####################'
}

__SGO_DEBUG_END () {
	true '#####################'
	true '#     SGO END       #'
	true '#####################'
}


sgo () {
	__SGO_DEBUG

	local arg opt val isVal rest
	local -A VARS
	local -A MODES
	local -A REAL_OPTS

	__SGO_PARSE_RULE "$__SGO_RULE"

	__SGO_SHIFT=0
	__SGO_IGNORED=

	for arg in "$@"; do
		if [[ $isVal == 1 ]]; then
			if [[ ${MODES[$opt]} == 3 ]]; then
				__SGO_HANDLE "$opt" "$arg"
			elif [[ ${MODES[$opt]} == 5 ]]; then
				__SGO_IGNORED+=" -$opt '$arg'"
			fi
			isVal=
		elif [[ $arg =~ ^-- ]]; then  # LONG OPTS

			arg=${arg: 2}
			opt=${arg%%=*}
			val=${arg#*=}

			# This is the '--' so we handle it as end of opts
			if [[ -z $opt ]]; then
				((__SGO_SHIFT++))
				__SGO_DEBUG_END
				return 0
			fi


			[[ -z ${VARS[$opt]} ]] && { echo "Option $opt is not acceptable in '$@'"; return 1; }

			if [[ ${MODES[$opt]} == 3 ]]; then # Mode: assign value to VAR
				[[ $val == $arg ]] && { echo "Argument for $opt not provided but needed"; return 1; }
				__SGO_HANDLE "${REAL_OPTS[$opt]}" "$val"
			elif [[ ${MODES[$opt]} == 5 ]]; then # Mode: ignore opt with value
				[[ $val == $arg ]] && { echo "Argument for $opt not provided but needed"; return 1; }
				__SGO_IGNORED+=" --$opt='$val'"
			elif [[ ${MODES[$opt]} == 4 ]]; then # Mode: ignore opt
				[[ $val != $arg ]] && { echo "Argument for $opt provided but not needed"; return 1; }
				__SGO_IGNORED+=" --$opt"
			else # Mode: increment VAR or assign value to VAR
				[[ $val != $arg ]] && { echo "Argument for $opt provided but not needed"; return 1; }
				__SGO_HANDLE "${REAL_OPTS[$opt]}"
			fi

		elif [[ $arg =~ ^- ]]; then  # SHORT OPTS

			while [[ ${#arg} -gt 1 ]]; do

				arg=${arg: 1}
				opt=${arg: 0:1}

				rest=${arg: 1}
				[[ -z ${VARS[$opt]} ]] && { echo "Option $opt is not acceptable in '$@'"; return 1; }

				if [[ ${MODES[$opt]} == 3 ]]; then # Mode: assign value to VAR
					if [[ -z $rest ]]; then
						isVal=1
					else # Mode: increment VAR or assign value to VAR
						__SGO_HANDLE "$opt" "$rest"
					fi
					break
				elif [[ ${MODES[$opt]} == 4 ]]; then # Mode: ignore opt
					__SGO_IGNORED+=" -$opt"
				elif [[ ${MODES[$opt]} == 5 ]]; then # Mode: ignore opt with value
					if [[ -z $rest ]]; then
						isVal=1
					else
						__SGO_IGNORED+=" -$opt'$rest'"
					fi
					break
				else
					__SGO_HANDLE "$opt"
				fi

			done
		else
			# This is the end of the opts
			__SGO_DEBUG_END
			return 0
		fi
		((__SGO_SHIFT++))
	done
	if [[ isVal == 1 ]]; then
		echo "Argument for $opt not provided but needed"
		return 1
	else
		__SGO_DEBUG_END
		return 0
	fi
}