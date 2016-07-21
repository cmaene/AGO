#!/bin/bash
# -------------------------------------------------------
# delete past/inactive users
# important! make sure to record all activities - run this like below
# ./delete_inactive_users.sh | tee processlog_output.txt
# -------------------------------------------------------

today=`date +"%m%d%y"`
rm process_log$today.csv #in case the file is already there
inputfile='test_users2.csv'

TOKEN=`curl --insecure -s -X POST --data 'username=xxxxx&password=xxxxx&referer=https://uchicago.maps.arcgis.com&expiration=20160&f=pjson' https://uchicago.maps.arcgis.com/sharing/rest/generateToken  | grep "token" | awk '{print $2}' | sed -e 's/[:|,|"]//g'`

echo "ESRIusername,ldapstatus,deleted,reassigned" > process_log$today.csv
sed 1d $inputfile | while IFS=, read -a line
do
    ESRIusername=""
    ldapstatus=""
    deleted=""
    reassigned=""
    echo ${line[0]}
    echo ${line[33]} 
    ESRIusername=${line[0]}
    ldapstatus=${line[33]}
	if [ "$ldapstatus" = "inactive" ]; then 
	    echo "inactive user detected - start deleting"
		curl --insecure -s -o response.txt -X POST --data 'f=pjson&token='$TOKEN https://uchicago.maps.arcgis.com/sharing/rest/community/users/$ESRIusername/delete
		if grep -q "error" response.txt; then
		    curl --insecure -s -o createFolder.txt -X POST --data 'f=pjson&token='$TOKEN'&title='$ESRIusername https://uchicago.maps.arcgis.com/sharing/rest/content/users/past_users/createFolder
		    if grep -q -E "success|not available" createFolder.txt; then
		        jsarray=`curl --insecure -s 'https://uchicago.maps.arcgis.com/sharing/rest/content/users/'$ESRIusername'?f=pjson&token='$TOKEN | jsawk 'return this.items' | jsawk 'return this.id'`
                string=`echo $jsarray | sed -r -e 's/\[|\]|"//g'`
                #echo $string
                IFS=',' read -r -a array <<< "$string"
                #total_items=`echo ${#array[@]}`
                for ((i=0; i<${#array[@]}; ++i)) ; do
                    curl --insecure -s -o reassign.txt -X POST --data 'f=pjson&token='$TOKEN'&targetUsername=past_users&targetFolderName='$ESRIusername https://uchicago.maps.arcgis.com/sharing/rest/content/users/$ESRIusername/items/${array[i]}/reassign
				    if grep -q "success" reassign.txt; then
                        reassigned="reassigned succefully"
                        echo $reassigned
                    else
                        reassigned="reassignment failed"
                    fi
                done
            else
				echo "couldn't create a folder"
            fi
            curl --insecure -s -o response.txt -X POST --data 'f=pjson&token='$TOKEN https://uchicago.maps.arcgis.com/sharing/rest/community/users/$ESRIusername/delete
            if grep -q "error" response.txt; then
                deleted="inactive-still can't delete" # often reasons are: (1) own a group, (2) own additional folder(s)
            elif grep -q "success" response.txt; then
                deleted="deleted successfully"
            else
                deleted="inactive-delete problem I don't know"
            fi
        elif grep -q "success" response.txt; then
            deleted="deleted successfully"
            reassigned="no items were reassign"
        else
            deleted="delete problem I don't know"
            reassigned="no items were reassign"
        fi
	else
		deleted="active user is not deleted"
		reassigned="active user items untouched if any"
	fi
	echo $ESRIusername","$ldapstatus","$deleted","$reassigned >> process_log$today.csv
done
