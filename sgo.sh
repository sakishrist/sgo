#!/bin/bash

__SGO_PARSE_RULE () {
	
	cleanRule () {
		rule=${rule%%'}'}
		rule=${rule##'{'}
		
		rule=${rule##'!{'}
		
		
		rule=${rule%%']'}
		rule=${rule##'['}
		
		rule=${rule##'!['}
	}
	
	ruleEnclosedIn () {
		[[ ${rule:0:${#1}} != "$1" ]] && return 1
		[[ ${rule: -${#2}} != "$2" ]] && return 1
		return 0
	}
	
	# Some local variables
	local mode rule elem aliasOpt mainOpt var expr
	
	while read line; do
		expr+=" ${line%%\#*}"
	done <<< "$*"
	
	local IFS=$' \t\n'
	
	for elem in $expr; do
		
		if [[ $elem == *'='* ]]; then
			var=${elem%%=*}
		fi
		mandatoryVar=$( [[ ${var:0:1} == '!' ]]; echo $?; )
		var=${var#'!'}
		rule=${elem#*=}

		if ruleEnclosedIn '[' ']'; then
			if [[ $mandatoryVar == "0" ]]; then
				echo "Var '$var' is set mandatory in flag mode. This is unsuported." >&2
				return 1
			fi
			if [[ $rule = *'|'* ]]; then
				mode=2
			else
				mode=1
			fi
		elif ruleEnclosedIn '{' '}'; then
			mode=3
		elif ruleEnclosedIn '![' ']'; then
			mode=4
		elif ruleEnclosedIn '!{' '}'; then
			mode=5
		else
			echo "syntax error: Rule '$rule' is not enclosed in [...] or {...}" >&2
			return 1
		fi

		cleanRule
		
		for opt in ${rule//|/ }; do
			mainOpt=${opt%%<*}
			aliasOpt=${opt#*<}; aliasOpt=${aliasOpt%>}

			if [[ -z $mainOpt ]]; then
				echo "syntax error: empty opt" >&2
				return 1
			fi

			VARS["$mainOpt"]="$var"
			MODES["$mainOpt"]="$mode"
			REAL_OPTS["$mainOpt"]="$mainOpt"

			if [[ $mandatoryVar == 0 ]]; then # 0 means yes
				MANDATORY_VARS["$var"]=1 # 1 means not processed
			fi

			if [[ -n $aliasOpt ]]; then
				VARS["$aliasOpt"]="$var"
				MODES["$aliasOpt"]="$mode"
				REAL_OPTS["$aliasOpt"]="$mainOpt"
			fi
		done
	done
	unset isMandDie cleanRule
}

__SGO_HANDLE () {
	local opt="$1"
	local value="$2"
	local var

	if [[ ${MODES[$opt]} == 1 ]]; then # Mode: increment VAR
		eval "((${VARS[$opt]}++))"
	elif [[ ${MODES[$opt]} == 2 ]]; then # Mode: assign option to VAR
		eval "${VARS[$opt]}=$opt"
	elif [[ ${MODES[$opt]} == 3 ]]; then # Mode: assign value to VAR
		if [[ ${BASH_VERSINFO[0]} -lt 4 || ( ${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -lt 3 ) ]]; then
			value="${value//\"/\"}"
		else
			value="${value//\"/\\\"}"
		fi
		var="${VARS[$opt]}"
		eval "$var=\"$value\""
		MANDATORY_VARS["$var"]=0 # means processed
	fi
	#eval "echo ${VARS[$opt]}=\"\$${VARS[$opt]}\""
}

sgoInit () {
	__SGO_RULE="$*"
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
	local -A MANDATORY_VARS

	__SGO_PARSE_RULE "$__SGO_RULE"

	__SGO_SHIFT=0
	__SGO_IGNORED=()

	for arg in "$@"; do
		origArg="$arg"
		
		if [[ $isVal == 1 ]]; then
			if [[ ${MODES[$opt]} == 3 ]]; then
				__SGO_HANDLE "$opt" "$arg"
			elif [[ ${MODES[$opt]} == 5 ]]; then
				__SGO_IGNORED+=("$origArg")
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


			[[ -z ${MODES[$opt]} ]] && { echo "Option $opt is not acceptable in '$*'" >&2; return 1; }

			if [[ ${MODES[$opt]} == 3 ]]; then # Mode: assign value to VAR
				[[ $val == "$arg" ]] && { echo "Argument for $opt not provided but needed" >&2; return 1; }
				__SGO_HANDLE "${REAL_OPTS[$opt]}" "$val"
			elif [[ ${MODES[$opt]} == 5 ]]; then # Mode: ignore opt with value
				[[ $val == "$arg" ]] && { echo "Argument for $opt not provided but needed" >&2; return 1; }
				__SGO_IGNORED+=("$origArg")
			elif [[ ${MODES[$opt]} == 4 ]]; then # Mode: ignore opt
				[[ $val != "$arg" ]] && { echo "Argument for $opt provided but not needed" >&2; return 1; }
				__SGO_IGNORED+=("$origArg")
			else # Mode: increment VAR or assign value to VAR
				[[ $val != "$arg" ]] && { echo "Argument for $opt provided but not needed" >&2; return 1; }
				__SGO_HANDLE "${REAL_OPTS[$opt]}"
			fi

		elif [[ $arg =~ ^- ]]; then  # SHORT OPTS
			while [[ ${#arg} -gt 1 ]]; do

				arg=${arg: 1}
				opt=${arg: 0:1}

				rest=${arg: 1}
				[[ -z ${MODES[$opt]} ]] && { echo "Option $opt is not acceptable in '$*'" >&2; return 1; }

				if [[ ${MODES[$opt]} == 3 ]]; then # Mode: assign value to VAR
					if [[ -z $rest ]]; then
						isVal=1
					else # Mode: increment VAR or assign value to VAR
						__SGO_HANDLE "$opt" "$rest"
					fi
					break
				elif [[ ${MODES[$opt]} == 4 ]]; then # Mode: ignore opt
					__SGO_IGNORED+=("$origArg")
				elif [[ ${MODES[$opt]} == 5 ]]; then # Mode: ignore opt with value
					if [[ -z $rest ]]; then
						isVal=1
					fi
					__SGO_IGNORED+=("$origArg")
					break
				else
					__SGO_HANDLE "$opt"
				fi

			done
		else
			break;
		fi
		((__SGO_SHIFT++))
	done
	
	if [[ $isVal == 1 ]]; then
		echo "Argument for $opt not provided but needed" >&2
		return 1
	fi
	
	for i in "${MANDATORY_VARS[@]}"; do
		if [[ $i != 0 ]]; then
			echo "Some mandatory options are missing" >&2
			return 1
		fi
	done
	
	__SGO_DEBUG_END
	return 0
}
