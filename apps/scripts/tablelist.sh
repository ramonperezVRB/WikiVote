#!/bin/bash

#This script updates the table of legislation that links to the main page

#Call the WikiVote API to login and retrieve an edit token for the WikiVote page
. ./wikivote-login.sh

#Some parameters: Session is the session of congress.  Chamber is either House, Senate, or Both.
#Type is either Introduced, Updated, Active, Passed, Enacted, or Vetoed
SESSION=115
CHAMBER=$1
TYPE=active

#Set some wiki markup language based on the image of either the House or Senate seal
if [ "$CHAMBER" == "house" ]; then
        PAGE_TITLE="U.S. House of Representatives"
elif [ "$CHAMBER" == "senate" ]; then
        PAGE_TITLE="U.S. Senate"
fi

for FILE in ~/apps/propublica/bills/${CHAMBER}/${SESSION}/*
do

#Parse the bill results to save the bill number, title, and summary as variables
BILL="$(jq '.results[].bill' ${FILE} | sed -e 's/^"//' -e 's/"$//')"
echo "${BILL}"
TITLE="$(jq '.results[].title' ${FILE} | sed -e 's/\"//g' -e 's/\\//g')"
#echo "${TITLE}"
SPONSOR_ID="$(jq '.results[].sponsor_id' ${FILE} | sed -e 's/^"//' -e 's/"$//')"
#echo "${SPONSOR_ID}"

#Once the edit token is retrieved, start editing the page
echo "${BILL}"
echo "${TITLE}"
echo "${SPONSOR_ID}"

#Go to the table page and add a new bullet to the list, including the bill number and title
CR=$(curl -S \
        --location \
        --cookie $cookie_jar \
        --cookie-jar $cookie_jar \
        --user-agent "Curl Shell Script" \
        --keepalive-time 60 \
        --header "Accept-Language: en-us" \
        --header "Connection: keep-alive" \
        --compressed \
        --data-urlencode "title=${PAGE_TITLE}" \
        --data-urlencode "appendtext="$'\n'"*[[${BILL}]]: ${TITLE}" \
        --data-urlencode "token=${EDITTOKEN}" \
        --request "POST" "${WIKIAPI}?action=edit&format=json")

done

exit 0
