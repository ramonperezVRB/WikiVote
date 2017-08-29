#!/usr/bin/env bash

#Needs curl
USERNAME="${WIKIVOTE_USER}"
USERPASS="${WIKIVOTE_PASS}"
WIKIAPI="http://wikivote.co/api.php"
cookie_jar="wikicj"
#Will store file in wikifile

echo "UTF8 check: ☠"
#################login
echo "Logging into $WIKIAPI as $USERNAME..."
#Login part 1
#printf "%s" "Logging in (1/2)..."
echo "Logging in (1/2)..."

CR=$(curl -S \
	--location \
	--retry 2 \
	--retry-delay 5\
	--cookie $cookie_jar \
	--cookie-jar $cookie_jar \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--data-urlencode "lgname=${USERNAME}" \
	--data-urlencode "lgpassword=${USERPASS}" \
	--request "POST" "${WIKIAPI}?action=query&meta=tokens&type=login&format=json")

CR2="${CR}"

#echo "$(sudo mv ${CR} ${CR}.json)"
#echo "$(jq '.warnings.main' $CR2)"

if [ "${CR2[9]}" = "[token]" ]; then
	TOKEN=${CR2[11]}
	echo "Logging in (1/2)...Complete"
else
	echo "Login part 1 failed."
	echo $CR2
	exit
fi

#Login part 2
echo "Logging in (2/2)..."
CR=$(curl -S \
	--location \
	--cookie $cookie_jar \
    --cookie-jar $cookie_jar \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--data-urlencode "lgname=${USERNAME}" \
	--data-urlencode "lgpassword=${USERPASS}" \
	--data-urlencode "lgtoken=${TOKEN}" \
	--request "POST" "${WIKIAPI}?action=login&format=txt")
	
#TODO-Add login part 2 check
echo "Successfully logged in as $USERNAME."

###############
#Get edit token
echo "Fetching edit token..."
CR=$(curl -S \
	--location \
	--cookie $cookie_jar \
	--cookie-jar $cookie_jar \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--request "POST" "${WIKIAPI}?action=query&meta=tokens&format=json")

CR2=($CR)
EDITTOKEN=${CR2[8]}
if [ ${#EDITTOKEN} = 34 ]; then
	echo "Edit token is: $EDITTOKEN"
else
	echo "Edit token not set."
	echo $CR
	exit
fi
#########################

curl "http://bits.wikimedia.org/images/wikimedia-button.png" >wikifile

CR=$(curl -S \
	--location \
	--cookie $cookie_jar \
	--cookie-jar $cookie_jar \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--header "Expect:" \
	--form "token=${EDITTOKEN}" \
	--form "filename=filename.gif" \
	--form "text=Filedescription" \
	--form "comment=commentDetails" \
	--form "file=@wikifile" \
	--request "POST" "${WIKIAPI}?action=upload&format=txt&")

echo $CR
read -p "Done..."
exit
