#!/bin/bash

#Some parameters: Session is the session of congress.  Chamber is either House, Senate, or Both.
#Type is either Introduced, Updated, Active, Passed, Enacted, or Vetoed
SESSION=115
CHAMBER=$1
TYPE=active

#Paginate through recent bills in batches of 20
COUNT=0
QUERY=0
BILL_COUNT=20
PAGINATE=20
NUMBER=0
STOP=2

while [ $BILL_COUNT -eq 20 ]
do

QUERY=$((NUMBER*PAGINATE))
#echo "${QUERY}"

#Get the most recent 20 bills introduced in Congress from the Propublica API
#sudo curl "https://api.propublica.org/congress/v1/${SESSION}/${CHAMBER}/bills/${TYPE}.json?offset=${QUERY}" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${TYPE}.json

#Count the number of bills returned, keeping a running tally
#BILL_COUNT="$(jq '.results[].num_results' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${TYPE}.json)"
BILL_COUNT="$(sudo curl "https://api.propublica.org/congress/v1/${SESSION}/${CHAMBER}/bills/${TYPE}.json?offset=${QUERY}" -H "X-API-Key: ${PROPUBLICA_API_KEY}" | jq '.results[].num_results')"
#echo "${BILL_COUNT}"
COUNT=$((COUNT+BILL_COUNT))
#echo "${COUNT}"

#Increment by one
NUMBER=$((NUMBER+1))

done

echo "The total number of ${TYPE} bills in the ${CHAMBER} for the ${SESSION}th Congress is ${COUNT}"

exit 0
