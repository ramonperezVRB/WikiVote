#!/bin/bash

#Get the most recent 20 bills introduced in Congress from the Propublica API
sudo curl "https://api.propublica.org/congress/v1/115/house/bills/introduced.json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/bills/introduced.json

for number in {0..19}
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
#curl "http://wikivote.co/api.php?action=edit&format=json&title=${BILL}&text=${TITLE}&summary=${SUMMARY}&basetimestamp=2007-08-24T12%3A34%3A54.000Z&token=d646e91b36d2ffaebd8f65ca8b09be1359a46b17%2B%5C"
done

exit 0
