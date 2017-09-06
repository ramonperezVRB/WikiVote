#!/bin/bash

#Some parameters: Session is the session of congress.  Chamber is either House, Senate, or Both.
#Type is either Introduced, Updated, Active, Passed, Enacted, or Vetoed
SESSION=115
CHAMBER=house
TYPE=active

#Get the most recent 20 bills introduced in Congress from the Propublica API
sudo curl "https://api.propublica.org/congress/v1/${SESSION}/${CHAMBER}/bills/${TYPE}.json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/bills/${TYPE}.json

for number in {0..1}
do

#Cycle through each bill in the list  and output the bill name to a variable
OUTPUT="$(jq '.results[].bills['$number'].bill_id' ~/apps/propublica/bills/${TYPE}.json)"

#Trim the output to remove quotations and Congressional session indicator"
echo  "${OUTPUT:1:-5}"
OUTPUT2="${OUTPUT:1:-5}"

#Call the Propublica API to find the given bill, saving the results to disk
sudo curl "https://api.propublica.org/congress/v1/115/bills/${OUTPUT2}.json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json

#Parse the bill results to save the bill number, title, and summary as variables
BILL="$(jq '.results[].bill' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${BILL}"
TITLE="$(jq '.results[].title' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${TITLE}"
SUMMARY="$(jq '.results[].summary_short' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${SUMMARY_SHORT}"
SUMMARY="$(jq '.results[].summary' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${SUMMARY}"
GPO_LINK="$(jq '.results[].gpo_pdf_uri' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${GPO_LINK}"
GPO_TEXT="Full text of the bill is available through the Government Publishing Office [${GPO_LINK}]"
echo "${GPO_TEXT}"
SPONSOR_ID="$(jq '.results[].sposor_id' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${OUTPUT2}.json | sed -e 's/^"//' -e 's/"$//')"
echo "${SPONSOR_ID}"



#Set some wiki markup language based on the image of either the House or Senate seal
if [ "$CHAMBER" == "house" ]; then
	IMAGE="[[File:Seal of the United States House of Representatives.png|200x200px|${BILL} is currently pending action in the U.S. House of Representatives|thumb]]"
elif [ "$CHAMBER" == "senate" ]; then
	IMAGE="[[File:US-Senate-UnofficialAltGreatSeal.png|200x200px|${BILL} is currently pending action in the United States Senate|thumb]]"
else
	IMAGE=" "
fi


#Call the WikiVote API to create a new Wiki page with the given bill number, title, and summary
. ./wiki-add.sh


done

exit 0
