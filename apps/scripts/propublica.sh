#!/bin/bash

#Call the WikiVote API to login and retrieve an edit token for the WikiVote page
. ./wikivote-login.sh

#Some parameters: Session is the session of congress.  Chamber is either House, Senate, or Both.
#Type is either Introduced, Updated, Active, Passed, Enacted, or Vetoed
SESSION=115
CHAMBER=house
TYPE=active

#Paginate through recent bills in batches of 20
COUNT=0
PAGINATE=20

for NUMBER in {0..24}
do

QUERY=$((NUMBER*PAGINATE))
#echo "${QUERY}"

#Get the most recent 20 bills introduced in Congress from the Propublica API
sudo curl "https://api.propublica.org/congress/v1/${SESSION}/${CHAMBER}/bills/${TYPE}.json?offset=${QUERY}" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${TYPE}.json

#Count the number of bills returned, keeping a running tally
BILL_COUNT="$(jq '.results[].num_results' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${TYPE}.json)"
COUNT=$((COUNT+BILL_COUNT))
echo "${COUNT}"


#Now pull the content from those 20 bills
for number2 in {0..19}
do

#Cycle through each bill in the list  and output the bill name to a variable
OUTPUT="$(jq '.results[].bills['$number2'].bill_id' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${TYPE}.json)"

#Remove the temporary file so the file directory only has JSON objects for each relevant bill
#sudo rm ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${TYPE}.json

#Trim the output to remove quotations and Congressional session indicator"
#echo  "${OUTPUT:1:-5}"
OUTPUT2="${OUTPUT:1:-5}"

#Call the Propublica API to find the given bill, saving the results to disk
sudo curl "https://api.propublica.org/congress/v1/115/bills/${OUTPUT2}.json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json

#Parse the bill results to save the bill number, title, and summary as variables
BILL="$(jq '.results[].bill' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${BILL}"
TITLE="$(jq '.results[].title' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/\"//g' -e 's/\\//g')"
#echo "${TITLE}"
SUMMARY_SHORT="$(jq '.results[].summary_short' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
#echo "${SUMMARY_SHORT}"
SUMMARY="$(jq '.results[].summary' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
#echo "${SUMMARY}"
GPO_LINK="$(jq '.results[].gpo_pdf_uri' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
#echo "${GPO_LINK}"
GPO_TEXT="Full text of the bill is available through the Government Publishing Office [${GPO_LINK}]"
#echo "${GPO_TEXT}"
SPONSOR_ID="$(jq '.results[].sposor_id' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
#echo "${SPONSOR_ID}"



#Set some wiki markup language based on the image of either the House or Senate seal
if [ "$CHAMBER" == "house" ]; then
	IMAGE="[[File:Seal of the United States House of Representatives.png|305x305px|${BILL} is currently pending action in the U.S. House of Representatives|thumb]]"
elif [ "$CHAMBER" == "senate" ]; then
	IMAGE="[[File:US-Senate-UnofficialAltGreatSeal.png|305x305px|${BILL} is currently pending action in the United States Senate|thumb]]"
else
	IMAGE=" "
fi


#Once the edit token is retrieved, start editing the page.  Add the appropriate image.
#echo "${BILL}"
#echo "${TITLE}"
#echo "${SUMMARY}"
#echo "${IMAGE}"
#echo "${GPO_TEXT}"

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
        

#Add the title
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

#Add the summary section
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

#Add the bill supporters section
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

#Add the bills opponents section
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

#Add the bill text section
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

#Add the bill explanation section
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


done

done

exit 0
