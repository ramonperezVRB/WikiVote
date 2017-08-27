#!/bin/bash
for number in {0..19}
do

OUTPUT="$(jq '.results[].bills['$number'].bill_id' ~/apps/propublica/introduced.json)"
echo  "${OUTPUT}"
#curl "https://api.propublica.org/congress/v1/115/bills/"${NAME}".json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" | jq '.results[].bill_id'

done

exit 0
