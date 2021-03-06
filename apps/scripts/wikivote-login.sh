#!/usr/bin/env bash
source $HOME/.bash_profile

#Needs curl and jq

USERNAME="${WIKIVOTE_USER}"
USERPASS="${WIKIVOTE_PASS}"
WIKIAPI="http://wikivote.co/api.php"
FILE_PATH=~/apps/scripts
cookie_jar="wikicj"
#Will store file in wikifile

echo "UTF8 check: ☠"
#################login
echo "Logging into $WIKIAPI as $USERNAME..."

###############
#Login part 1
#printf "%s" "Logging in (1/2)..."
echo "Get login token..."

CR=$(sudo curl -S \
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
	--request "GET" "${WIKIAPI}?action=query&meta=tokens&type=login&format=json")

echo "$CR" | jq .

#sudo rm login.json
sudo echo "$CR" > $FILE_PATH/login.json
TOKEN=$(jq --raw-output '.query.tokens.logintoken' $FILE_PATH/login.json)
TOKEN="${TOKEN//\"/}" #replace double quote by nothing

#Remove carriage return!
printf "%s" "$TOKEN" > $FILE_PATH/token.txt
TOKEN=$(cat $FILE_PATH/token.txt | sed 's/\r$//')

if [ "$TOKEN" == "null" ]; then
	echo "Getting a login token failed."
	exit
else
	echo "Login token is $TOKEN"
	echo "-----"
fi

###############
#Login part 2
echo "Logging in..."

CR=$(sudo curl -S \
	--location \
	--cookie $cookie_jar \
        --cookie-jar $cookie_jar \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--data-urlencode "username=${USERNAME}" \
	--data-urlencode "password=${USERPASS}" \
	--data-urlencode "rememberMe=1" \
	--data-urlencode "logintoken=${TOKEN}" \
	--data-urlencode "loginreturnurl=http://wikivote.co" \
	--request "POST" "${WIKIAPI}?action=clientlogin&format=json")

echo "$CR" | jq .

STATUS=$(echo $CR | jq '.clientlogin.status')
if [[ $STATUS == *"PASS"* ]]; then
	echo "Successfully logged in as $USERNAME, STATUS is $STATUS."
	echo "-----"
else
	echo "Unable to login, is logintoken ${TOKEN} correct?"
	exit
fi

###############
#Get edit token
echo "Fetching edit token..."

CR=$(sudo curl -S \
	--location \
	--cookie $cookie_jar \
	--cookie-jar $cookie_jar \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--request "POST" "${WIKIAPI}?action=query&meta=tokens&format=json")

echo "$CR" | jq .

echo "$CR" > $FILE_PATH/edittoken.json
EDITTOKEN=$(jq --raw-output '.query.tokens.csrftoken' $FILE_PATH/edittoken.json)
#sudo rm edittoken.json

EDITTOKEN="${EDITTOKEN//\"/}" #replace double quote by nothing

#Remove carriage return!
printf "%s" "$EDITTOKEN" > $FILE_PATH/edittoken.txt
EDITTOKEN=$(cat $FILE_PATH/edittoken.txt | sed 's/\r$//')

if [[ $EDITTOKEN == *"+\\"* ]]; then
	echo "Edit token is: $EDITTOKEN"
else
	echo "Edit token not set."
	exit
fi


