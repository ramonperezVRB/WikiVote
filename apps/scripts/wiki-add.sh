#!/usr/bin/env bash

#Needs curl and jq

USERNAME="${WIKIVOTE_USER}"
USERPASS="${WIKIVOTE_PASS}"
WIKIAPI="http://wikivote.co/api.php"
cookie_jar="wikicj"
#Will store file in wikifile

echo "UTF8 check: ☠"
#################login
echo "Logging into $WIKIAPI as $USERNAME..."

###############
#Login part 1
#printf "%s" "Logging in (1/2)..."
echo "Get login token..."
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
	--request "GET" "${WIKIAPI}?action=query&meta=tokens&type=login&format=json")

echo "$CR" | jq .

sudo rm login.json
sudo echo "$CR" > login.json
TOKEN=$(jq --raw-output '.query.tokens.logintoken' login.json)
TOKEN="${TOKEN//\"/}" #replace double quote by nothing

#Remove carriage return!
printf "%s" "$TOKEN" > token.txt
TOKEN=$(cat token.txt | sed 's/\r$//')


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
CR=$(curl -S \
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

echo "$CR" | jq .
echo "$CR" > edittoken.json
EDITTOKEN=$(jq --raw-output '.query.tokens.csrftoken' edittoken.json)
sudo rm edittoken.json

EDITTOKEN="${EDITTOKEN//\"/}" #replace double quote by nothing

#Remove carriage return!
printf "%s" "$EDITTOKEN" > edittoken.txt
EDITTOKEN=$(cat edittoken.txt | sed 's/\r$//')

if [[ $EDITTOKEN == *"+\\"* ]]; then
	echo "Edit token is: $EDITTOKEN"
else
	echo "Edit token not set."
	exit
fi

###############
#Make a test edit
echo "${BILL}"
echo "${TITLE}"
echo "${SUMMARY}"
echo "${IMAGE}"
echo "${GPO_TEXT}"

CR=$(curl -S \
        --location \
        --cookie $cookie_jar \
        --cookie-jar $cookie_jar \
        --user-agent "Curl Shell Script" \
        --keepalive-time 60 \
        --header "Accept-Language: en-us" \
        --header "Connection: keep-alive" \
        --compressed \
        --data-urlencode "title=${BILL}" \
        --data-urlencode "appendtext=${IMAGE}" \
        --data-urlencode "token=${EDITTOKEN}" \
        --request "POST" "${WIKIAPI}?action=edit&format=json")
        
echo "$CR" | jq .

CR=$(curl -S \
	--location \
	--cookie $cookie_jar \
	--cookie-jar $cookie_jar \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--data-urlencode "title=${BILL}" \
        --data-urlencode "section=new" \
        --data-urlencode "sectiontitle=Title" \
        --data-urlencode "appendtext=${TITLE}" \
	--data-urlencode "token=${EDITTOKEN}" \
	--request "POST" "${WIKIAPI}?action=edit&format=json")
	
echo "$CR" | jq .

CR=$(curl -S \
        --location \
        --cookie $cookie_jar \
        --cookie-jar $cookie_jar \
        --user-agent "Curl Shell Script" \
        --keepalive-time 60 \
        --header "Accept-Language: en-us" \
        --header "Connection: keep-alive" \
        --compressed \
        --data-urlencode "title=${BILL}" \
        --data-urlencode "section=new" \
        --data-urlencode "sectiontitle=Summary" \
        --data-urlencode "appendtext=${SUMMARY} " \
        --data-urlencode "token=${EDITTOKEN}" \
        --request "POST" "${WIKIAPI}?action=edit&format=json")
        
echo "$CR" | jq .

CR=$(curl -S \
        --location \
        --cookie $cookie_jar \
        --cookie-jar $cookie_jar \
        --user-agent "Curl Shell Script" \
        --keepalive-time 60 \
        --header "Accept-Language: en-us" \
        --header "Connection: keep-alive" \
        --compressed \
        --data-urlencode "title=${BILL}" \
        --data-urlencode "section=new" \
        --data-urlencode "sectiontitle=What the bill's supporters say" \
        --data-urlencode "appendtext=Supporters of the bill should edit this section to offer information about the potential positive impacts of the legislation. Be sure to reference the substantive policy components of the specific legislation, rather than general ideological or political positions." \
        --data-urlencode "token=${EDITTOKEN}" \
        --request "POST" "${WIKIAPI}?action=edit&format=json")
        
echo "$CR" | jq .

CR=$(curl -S \
        --location \
        --cookie $cookie_jar \
        --cookie-jar $cookie_jar \
        --user-agent "Curl Shell Script" \
        --keepalive-time 60 \
        --header "Accept-Language: en-us" \
        --header "Connection: keep-alive" \
        --compressed \
        --data-urlencode "title=${BILL}" \
        --data-urlencode "section=new" \
        --data-urlencode "sectiontitle=What the bill's opponents say" \
        --data-urlencode "appendtext=Opponents of the bill should edit this section to offer information about the potential negative impacts of the legislation. Be sure to reference the substantive policy components of the specific legislation, rather than general ideological or political positions." \
        --data-urlencode "token=${EDITTOKEN}" \
        --request "POST" "${WIKIAPI}?action=edit&format=json")
        
echo "$CR" | jq .

CR=$(curl -S \
        --location \
        --cookie $cookie_jar \
        --cookie-jar $cookie_jar \
        --user-agent "Curl Shell Script" \
        --keepalive-time 60 \
        --header "Accept-Language: en-us" \
        --header "Connection: keep-alive" \
        --compressed \
        --data-urlencode "title=${BILL}" \
        --data-urlencode "section=new" \
        --data-urlencode "sectiontitle=Text of the Bill" \
        --data-urlencode "appendtext=${GPO_TEXT}" \
        --data-urlencode "token=${EDITTOKEN}" \
        --request "POST" "${WIKIAPI}?action=edit&format=json")
        
echo "$CR" | jq .

CR=$(curl -S \
        --location \
        --cookie $cookie_jar \
        --cookie-jar $cookie_jar \
        --user-agent "Curl Shell Script" \
        --keepalive-time 60 \
        --header "Accept-Language: en-us" \
        --header "Connection: keep-alive" \
        --compressed \
        --data-urlencode "title=${BILL}" \
        --data-urlencode "section=new" \
        --data-urlencode "sectiontitle=Explanation of the Bill" \
        --data-urlencode "appendtext=This section is meant for a plain language (not legalese) explanation of how the law is intended to work" \
        --data-urlencode "token=${EDITTOKEN}" \
        --request "POST" "${WIKIAPI}?action=edit&format=json")
        
echo "$CR" | jq .
