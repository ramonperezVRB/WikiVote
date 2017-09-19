#!/bin/bash
source $HOME/.bash_profile

#Some parameters: Session is the session of congress.  Chamber is either House or Senate. Session between 102-115
CHAMBER=$1
SESSION=$2
NUMBER=0

#If the folder doesn't exist, create it
sudo mkdir -p ~/apps/propublica/members/${CHAMBER}/${SESSION}

#Query propublica do get a count of the members in a given session of that chamber of Congress
sudo curl "https://api.propublica.org/congress/v1/${SESSION}/${CHAMBER}/members.json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/members/${CHAMBER}/${SESSION}/members.json
MEMBER_COUNT="$(jq '.results[].num_results' ~/apps/propublica/members/${CHAMBER}/${SESSION}/members.json)"
#echo "${MEMBER_COUNT}"

for NUMBER in $(seq 0 $MEMBER_COUNT)
do

	#Retrieve the member ID of each member from the list of members.json
	MEMBER_ID="$(jq '.results[].members['$NUMBER'].id' ~/apps/propublica/members/${CHAMBER}/${SESSION}/members.json | sed -e 's/^"//' -e 's/"$//')"
	echo "${MEMBER_ID}"

	#Query propublica to retrieve contents for each member by a given member ID
	sudo curl "https://api.propublica.org/congress/v1/members/${MEMBER_ID}.json" -H "X-API-Key: ${PROPUBLICA_API_KEY}" -o ~/apps/propublica/members/${CHAMBER}/${SESSION}/${MEMBER_ID}.json

done

echo "The total number of members in the ${CHAMBER} for the ${SESSION}th Congress is ${MEMBER_COUNT}. Added member files to the following location: ~/apps/propublica/members/${CHAMBER}/${SESSION}/"

exit 0
