#!/bin/bash

#This script updates the table of legislation that links to the main page

#Call the WikiVote API to login and retrieve an edit token for the WikiVote page
. ./wikivote-login.sh

#Some parameters: Session is the session of congress.  Chamber is either House, Senate, or Both.
#Type is either Introduced, Updated, Active, Passed, Enacted, or Vetoed
SESSION=115
CHAMBER=senate
TYPE=Active
LIST_FILE=~/apps/scripts/list.txt

#Build a text file that will ultimately be uploaded to WikiVote
ADD_TEXT="== ${TYPE} Legislation in the ${SESSION}th Congress =="
#echo "${ADD_TEXT}"
sudo echo "$ADD_TEXT" > "$LIST_FILE"

#Add the template headers to indicate that it is a sortable wikitable"
ADD_TEXT=$'\n'$'{| class="wikitable sortable"'$'\n'"|-"$'\n'"! Bill !! Title"
#echo "${ADD_TEXT}"
echo "$ADD_TEXT" >> "$LIST_FILE"

#Set some wiki markup language based on the image of either the House or Senate seal
if [ "$CHAMBER" == "house" ]; then
        PAGE_TITLE="U.S. House of Representatives"
elif [ "$CHAMBER" == "senate" ]; then
        PAGE_TITLE="U.S. Senate"
fi

#Look through all of the bills on file that have been pulled from Propublica and stored locally
for FILE in ~/apps/propublica/bills/${CHAMBER}/${SESSION}/*
do

#Parse the bill results to save the bill number, title, and summary as variables
BILL="$(jq '.results[].bill' ${FILE} | sed -e 's/^"//' -e 's/"$//')"
#echo "${BILL}"
TITLE="$(jq '.results[].title' ${FILE} | sed -e 's/\"//g' -e 's/\\//g')"
#echo "${TITLE}"
SPONSOR_ID="$(jq '.results[].sposor_id' ${FILE} | sed -e 's/^"//' -e 's/"$//')"
#echo "${SPONSOR_ID}"

#Add the bill number and title to a new line in the table
ADD_TEXT="|-"$'\n'"| [[${BILL}]] || ${TITLE} "

if [ -f "$LIST_FILE" ]
then 
    echo "$ADD_TEXT" >> "$LIST_FILE"
fi

done

#After exiting the loop, close the wikitable template with curly brackets
ADD_TEXT="|}"
#echo "${ADD_TEXT}"

if [ -f "$LIST_FILE" ]
then 
    echo "$ADD_TEXT" >> "$LIST_FILE"
fi

#Pull the contents of the file into a string to pass through curl
TEXT=$(<"$LIST_FILE")
#echo "$TEXT"

#Send the contents of the text to WikiVote
CR=$(curl -S \
        --location \
        --cookie $cookie_jar \
        --cookie-jar $cookie_jar \
        --user-agent "Curl Shell Script" \
        --keepalive-time 60 \
        --header "Accept-Language: en-us" \
        --header "Connection: keep-alive" \
        --compressed \
        --data-urlencode "title=Table demo" \
        --data-urlencode "appendtext=${TEXT}" \
        --data-urlencode "token=${EDITTOKEN}" \
        --request "POST" "${WIKIAPI}?action=edit&format=json")


exit 0
