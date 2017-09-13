#!/bin/bash

#Some parameters: Session is the session of congress.  Chamber is either House, Senate, or Both.
#Type is either Introduced, Updated, Active, Passed, Enacted, or Vetoed
SESSION=115
CHAMBER=house
TYPE=active

#Paginate through recent bills in batches of 20
COUNT=0
PAGINATE=20
STOP=1

for NUMBER in {0.."${STOP}"}
do

QUERY=$((NUMBER*PAGINATE))
#echo "${QUERY}"

#Get the most recent 20 bills introduced in Congress from the Propublica API
sudo curl "https://api.propublica.org/congress/v1/${SESSION}/${CHAMBER}/bills/${TYPE}.json?offset=${QUERY}" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${TYPE}.json

#Count the number of bills returned, keeping a running tally
BILL_COUNT="$(jq '.results[].num_results' ~/apps/propublica/bills/${CHAMBER}/${SESSION}/${TYPE}.json)"
COUNT=$((COUNT+BILL_COUNT))
echo "${COUNT}"

if [ "${STOP}"="${COUNT}" ]
then
	STOP=$((STOP+1))
	echo "${STOP}"
fi

done
