#!/bin/bash

#Get the most recent 20 bills introduced in Congress from the Propublica API
sudo curl "https://api.propublica.org/congress/v1/115/house/bills/introduced.json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/bills/introduced.json

for number in {0..0}
do

#Cycle through each bill in the list  and output the bill name to a variable
OUTPUT="$(jq '.results[].bills['$number'].bill_id' ~/apps/propublica/bills/introduced.json)"

#Trim the output to remove quotations and Congressional session indicator"
echo  "${OUTPUT:1:-5}"
OUTPUT2="${OUTPUT:1:-5}"

#Call the Propublica API to find the given bill, saving the results to disk
sudo curl "https://api.propublica.org/congress/v1/115/bills/${OUTPUT2}.json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/bills/${OUTPUT2}.json

#Parse the bill results to save the bill number, title, and summary as variables
BILL="$(jq '.results[].bill' ~/apps/propublica/bills/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${BILL}"
TITLE="$(jq '.results[].title' ~/apps/propublica/bills/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${TITLE}"
SUMMARY="$(jq '.results[].summary' ~/apps/propublica/bills/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${SUMMARY}"

#Call the WikiVote API to create a new Wiki page with the given bill number, title, and summary

USERNAME="${WIKIVOTE_USER}"
USERPASS="${WIKIVOTE_PASS}"
WIKIAPI="http://wikivote.co/api.php"
cookie_jar="wikicj"

#Retrieve a login token from the wiki api and store it as JSON
sudo curl "${WIKIAPI}?action=query&format=json&meta=tokens&type=login" -H 'Content-Type: application/x-www-form-urlencoded' -b '${cookie_jar}' -o token.json
#echo "$(jq '.query.tokens.logintoken' token.json)"
#sudo iconv -f ASCII//TRANSLIT -t UTF-8 token.json -o newtoken.json
#echo "$(jq '.' newtoken.json)"

#Parse the token from the JSON object and strip off the quotes
TOKEN1="$(jq '.query.tokens.logintoken' token.json | sed -e 's/^"//' -e 's/"$//')"

#Save the new token as LOGINTOKEN to pass back to wiki 
LOGINTOKEN="${TOKEN1::-1}"
#LOGINTOKEN="${TOKEN1::-3}%2B%5C"
#iconv -f ASCII//TRANSLIT -t UTF-8 ${TOKEN1} -o LOGINTOKEN
echo "${LOGINTOKEN}"

#sudo curl -X POST -d 'action=clientlogin&username=${USERNAME}&password=${USERPASS}&rememberMe=1&format=json&logintoken=${LOGINTOKEN}' -H 'Content-Type: application/x-www-form-urlencoded' -b '${cookie_jar}' -o results.json "${WIKIAPI}"
sudo curl -X POST -d 'action=login&lgname=${USERNAME}&lgpassword=${USERPASS}&format=json&lgtoken=${LOGINTOKEN}' -H 'Content-Type: application/x-www-form-urlencoded' -b '${cookie_jar}' -o results.json "${WIKIAPI}"
echo "$(jq '.' results.json)"
TOKEN="$(jq '.login.token' results.json | sed -e 's/^"//' -e 's/"$//')"
LOGINTOKEN="${TOKEN::-1}"
sudo curl -X POST -d 'action=login&lgname=${USERNAME}&lgpassword=${USERPASS}&format=json&lgtoken=${LOGINTOKEN}' -H 'Content-Type: application/x-www-form-urlencoded' -b '${cookie_jar}' -o results2.json "${WIKIAPI}"
echo "$(jq '.' results2.json)"

#Once logged in, we can retrieve a CSRF token for editing
sudo curl "${WIKIAPI}?action=query&format=json&meta=tokens&type=csrf" -H 'Content-Type: application/x-www-form-urlencoded' -b '${cookie_jar}' -o token2.json
TOKEN2="$(jq '.query.tokens.csrftoken' token2.json | sed -e 's/^"//' -e 's/"$//' -e 's/[/]$//')"
CSRFTOKEN="${TOKEN2::-1}"
echo "${CSRFTOKEN}"

#CR=$(curl -S \
#       --location \
#       --cookie $cookie_jar \
#       --cookie-jar $cookie_jar \
#       --user-agent "Curl Shell Script" \
#       --keepalive-time 60 \
#       --header "Accept-Language: en-us" \
#       --header "Connection: keep-alive" \
#       --header "Expect:" \
#       --form "meta=tokens" \
#       --form "type=login" \
#       --form "format=json" \
#       --form "lgname=${USERNAME}" \
#       --request "GET" "${WIKIAPI}?action=query&format=json")

#echo "${CR}"


#CR2=$(curl -S \
#       --location \
#       --cookie $cookie_jar \
#       --cookie-jar $cookie_jar \
#       --user-agent "Curl Shell Script" \
#       --keepalive-time 60 \
#       --header "Accept-Language: en-us" \
#       --header "Connection: keep-alive" \
#       --header "Expect:" \
#       --form "format=json" \
#       --form "lgname=${USERNAME}" \
#       --form "lgpassword=${USERPASS}" \
#       --form "lgtoken=${LOGINTOKEN}%2B%5C" \
#       --request "POST" "${WIKIAPI}?action=login&format=json")

#echo "${CR2}"


#TOKEN1="$(jq '.query.tokens.logintoken' token.json | sed -e 's/^"//' -e 's/"$//')"
#LOGINTOKEN="${TOKEN1::-3}"
#echo "${LOGINTOKEN}"
#TOKEN2="$(jq '.query.tokens.csrftoken' token.json | sed -e 's/^"//' -e 's/"$//' -e 's/[/]$//')"
#CSRFTOKEN="${TOKEN2::-1}"
#echo "${CSRFTOKEN}"

#sudo curl "http://wikivote.co/api.php?action=edit&format=json&title=${BILL}&text=${TITLE}&summary=${SUMMARY}&token=${LOGINTOKEN}" -o results.json
#echo "$(jq '.' results.json)"

#sudo curl "http://bits.wikimedia.org/images/wikimedia-button.png" -o wikifile
#sudo curl "http://a.abcnews.com/images/US/hurricane-harvey-03-gty-jc-170825_16x9_992.jpg" -o wikifile
#sudo curl "http://textfiles.com/100/914bbs.txt" -o wikifile

#CR=$(curl -S \
#       --location \
#       --cookie $cookie_jar \
#       --cookie-jar $cookie_jar \
#       --user-agent "Curl Shell Script" \
#       --keepalive-time 60 \
#       --header "Accept-Language: en-us" \
#       --header "Connection: keep-alive" \
#       --header "Expect:" \
#       --form "token=${LOGINTOKEN}%2B%5C" \
#       --form "filename=filename.gif" \
#       --form "text=Filedescription" \
#       --form "comment=commentDetails" \
#       --form "file=@wikifile" \
#       --form "format=json" \
#       --request "POST" "${WIKIAPI}?action=upload&")
#       --request "POST" "${WIKIAPI}?action=edit&format=json&title=${BILL}&text=${TITLE}&summary=${SUMMARY}&")

#echo "${CR}"

#sudo curl "${WIKIAPI}?action=upload&filename=Test&file=${wikifile}&token=${LOGINTOKEN}&format=json" -o results2.json

#echo "$(jq '.' results2.json)"

done

exit 0
