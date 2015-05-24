#!/bin/bash

# Variables initialisation
version="addKeychainPassword v0.1 - 2015, Yvan Godard [godardyvan@gmail.com]"
versionOSX=$(sw_vers -productVersion | awk -F '.' '{print $(NF-1)}')
scriptDir=$(dirname "${0}")
scriptName=$(basename "${0}")
scriptNameWithoutExt=$(echo "${scriptName}" | cut -f1 -d '.')
logActive=0
modeErase=""
userUid=$(whoami)
homeDir=$(echo ~)
log=${homeDir%/}/Library/logs/${scriptNameWithoutExt}.log
logTemp=$(mktemp /tmp/${scriptNameWithoutExt}_LogTemp.XXXXX)
help="no"

help () {
	echo -e "\n$version\n"
	echo -e "Cet outil est destiné à ajouter un mot de passe dans le trousseau du Mac d'un utilisateur."
	echo -e "\nAvertissement :"
	echo -e "Cet outil est mis à disposition sans aucune garantie ni support."
	echo -e "\nUtilisation :"
	echo -e "./$scriptName [-h] | -m <mode> -a <account> -s <service> -p <password>" 
	echo -e "                         [-e <supprimer>] [-j <fichier log>]"
	echo -e "\nPour afficher l'aide :"
	echo -e "\t-h:                  affiche cette aide et quitte"
	echo -e "\nParamètres obligatoires :"
	echo -e "\t-m <mode> :          type de mot de passe dans le trouseau. Doit être 'generic' ou 'internet'"
	echo -e "\t-a <account> :       contient le nom d'utilisateur (champ 'Compte' dans le trousseau)"
	echo -e "\t-s <service> :       nom du service (champ 'Nom' dans le trousseau)"
	echo -e "\t-p <password> :      mot de passe pour le Compte et le Service à ajouter"
	echo -e "\nParamètres optionnels :"
	echo -e "\t-e <supprimer> :     cette option permet de supprimer toutes les entrées correspondantes au même"
	echo -e "\t                     service dans le trousseau avant d'ajouter le mot de passe."
	echo -e "\t                     Utiliser '-e all' pour supprimer toutes les entrées du"
	echo -e "\t                     trousseau qui correspondent au service ou utiliser"
	echo -e "\t                     '-e thisaccount' pour supprimer uniquement les entrée du trousseau"
	echo -e "\t                     qui correspondent à la fois au même Compte et même Service."
	echo -e "\t-j <fichier log> :   active la journalisation à la place de la sortie standard."
	echo -e "\t                     Mettre en argument le chemin complet du fichier de log à utiliser"
	echo -e "\t                     (ex. : '/var/log/LDAP-rename.log') ou utilisez 'default' pour le chemin par défaut (${log})"
	exit 0
}

function error () {
	# Erreur 1 : problème d'ajout au trousseau
	# Erreur 2 : problème dans le remplissage des paramètres
	echo -e "\n*** Erreur ${1} ***"
	echo -e ${2}
	alldone ${1}
}

function alldone () {
	# Journalisation si nécessaire et redirection de la sortie standard
	[ ${1} -eq 0 ] && echo "" && echo "[${scriptName}] Processus terminé OK !"
	if [ ${logActive} -eq 1 ]; then
		exec 1>&6 6>&-
		[[ ! -f ${log} ]] && touch ${log}
		cat ${logTemp} >> ${log}
		cat ${logTemp}
	fi
	# Suppression des fichiers et répertoires temporaires
	[[ -f ${logTemp} ]] && rm -r ${logTemp}
	exit ${1}
}

# Vérification des options/paramètres du script 
optsCount=0
while getopts "hm:a:s:p:e:j:" option
do
	case "$option" in
		h)	help="yes"
						;;
	    s) 	service=${OPTARG}
			let optsCount=$optsCount+1
						;;
		a)	account=${OPTARG}
			let optsCount=$optsCount+1
						;;
	    m) 	mode=${OPTARG}
			[[ ${mode} != "generic" ]] && [[ ${mode} != "internet" ]] && error 2 "Le mode n'a pas été renseigné correctement : utiliser '-m generic' ou '-m internet'."
			let optsCount=$optsCount+1
						;;
		p)	password=${OPTARG}
						;;
		e)	[[ ${OPTARG} != "" ]] && [[ ${OPTARG} != "all" ]] && [[ ${OPTARG} != "thisaccount" ]] && error 2 "Le paramètre '-e' n'a pas été renseigné correctement : utiliser '-e all' ou '-e thisaccount'."
			modeErase=${OPTARG}
						;;
        j)	[[ ${OPTARG} != "default" ]] && log=${OPTARG}
			logActive=1
                        ;;
	esac
done

if [[ ${optsCount} != "3" ]]
	then
        help
        error 7 "Les paramètres obligatoires n'ont pas été renseignés."
fi

if [[ ${help} = "yes" ]]
	then
	help
fi

if [[ ${password} = "" ]]
	then
	echo "Entrez le mot de passe :" 
	read -s password
fi

# Redirection de la sortie strandard vers le fichier de log
if [ $logActive -eq 1 ]; then
	echo -e "\nMerci de patienter ..."
	exec 6>&1
	exec >> ${logTemp}
fi

echo ""
echo "****************************** `date` ******************************"
echo "${scriptName} démarré..."
echo "sur Mac OSX version $(sw_vers -productVersion)"

# Suppression des mots de passe
[[ ${modeErase} = "all" ]] && suiteCommandeSecurity="-s ${service}"
[[ ${modeErase} = "thisaccount" ]] && suiteCommandeSecurity="-s ${service} -a ${account}"

if [[ ${modeErase} = "all" ]] || [[ ${modeErase} = "thisaccount" ]] ; then
	security find-${mode}-password ${suiteCommandeSecurity} > /dev/null 2>&1
	arreterSuppression=$(echo $?)
	if [[ ${arreterSuppression} = "0" ]]; then
		suppCount=0
		[[ ${modeErase} = "all" ]] && echo "> Suppression de tous les mots de passe du service '${service}' :"
		[[ ${modeErase} = "thisaccount" ]] && echo "> Suppression de tous les mots de passe du service '${service}' et du compte '${account}' :"
		until [[ ${arreterSuppression} != "0" ]] 
			do 
			security delete-${mode}-password ${suiteCommandeSecurity} > /dev/null 2>&1
			codeRetour=${?}
			[[ ${codeRetour} -ne "0" ]] && echo "  - Attention, un problème a été rencontré lors de la suppression !"
			security find-${mode}-password ${suiteCommandeSecurity} > /dev/null 2>&1
			arreterSuppression=$(echo $?)
			let suppCount=$suppCount+1
		done
		[[ ${suppCount} = "1" ]] && echo "  - ${suppCount} entrée dans le trousseau a été supprimée."
		[[ ${suppCount} -gt "1" ]] && echo "  - ${suppCount} entrées dans le trousseau ont été supprimées."
	else
		[[ ${modeErase} = "all" ]] && echo "> Aucun mot de passe à supprimer pour le service '${service}'."
		[[ ${modeErase} = "thisaccount" ]] && echo "> Aucun mot de passe à supprimer pour le service '${service}' et le compte '${account}'."
	fi
fi

# Ajout du mot de passe
# Test si il y un mot de passe équivalent
pwline=$(security 2>&1 >/dev/null find-${mode}-password -a ${account} -s ${service} -g)
pwpart=${pwline#*\"}
if [[ ${pwpart%\"} = ${password} ]]; then
	echo "> Le mot de passe existe déjà dans le trousseau et est correct. Rien à faire de plus."
	alldone 0
elif [[ ${pwpart%\"} != ${password} ]]; then
	echo "> Suppression préalable des entrées équivalentes pour le service et le compte."
	suiteCommandeSecurity="-s ${service} -a ${account}"
	security find-${mode}-password ${suiteCommandeSecurity} > /dev/null 2>&1
	arreterSuppression=$(echo $?)
	if [[ ${arreterSuppression} = "0" ]]; then
		suppCount=0
		until [[ ${arreterSuppression} != "0" ]] 
			do 
			security delete-${mode}-password ${suiteCommandeSecurity} > /dev/null 2>&1
			codeRetour=${?}
			[[ ${codeRetour} -ne "0" ]] && echo "  - Attention, un problème a été rencontré lors de la suppression !"
			security find-${mode}-password ${suiteCommandeSecurity} > /dev/null 2>&1
			arreterSuppression=$(echo $?)
			let suppCount=$suppCount+1
		done
		[[ ${suppCount} = "1" ]] && echo "  - ${suppCount} entrée dans le trousseau a été supprimée."
		[[ ${suppCount} -gt "1" ]] && echo "  - ${suppCount} entrées dans le trousseau ont été supprimées."
	else
		echo -e "  - Aucun mot de passe à supprimer pour le service '${service}' et le compte '${account}'."
	fi
	# Ajout du mot de passe
	security add-${mode}-password -a ${account} -s ${service} -w ${password} > /dev/null 2>&1
	codeRetour=${?}
	[[ ${codeRetour} -ne "0" ]] && error 1 "Problème lors de l'ajout du mot de passe dans le trousseau."
	[[ ${codeRetour} -eq "0" ]] && echo "> Ajout du mot de passe réalisé avec succès !"
	alldone 0
fi
