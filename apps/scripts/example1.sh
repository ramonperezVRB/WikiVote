#!/bin/bash
for number in {0..1}
do

OUTPUT="$(jq '.results[].bills['$number'].bill_id' ~/apps/propublica/introduced.json)"
echo  "${OUTPUT:1:-5}"
OUTPUT2="${OUTPUT:1:-5}"
OUTPUT3="$(curl "https://api.propublica.org/congress/v1/115/bills/${OUTPUT2}.json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" | jq '.results[].bill,.results[].title,.results[].summary')"
#echo "${OUTPUT3}"

OUTPUT4="$(echo "${OUTPUT3}" | sed -e 's/^"//' -e 's/"$//')"
echo "${OUTPUT4}"

#curl "http://wikivote.co/api.php?action=edit&format=json&title=Test&text=article+content&summary=test+summary&basetimestamp=2007-08-24T12%3A34%3A54.000Z&token=d646e91b36d2ffaebd8f65ca8b09be1359a46b17%2B%5C"
done

exit 0
