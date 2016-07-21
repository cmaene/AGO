#!/bin/bash
# -------------------------------------------------------
# UChicago LDAP directory scraping
# input: userlist.csv - arcgis username in the first col
# to confirm the result, Jeff's analysis attached.
# -------------------------------------------------------
today=`date +"%m%d%y"`
rm ldap$today.txt #in case the file is already there
inputfile='export_users.csv'

## LDAP search
## uid uidNumber chicagoID cn mail telephoneNumber title eduPersonPrimaryAffiliation ucDepartment ou >ldif.csv
ldapheader='cnetID,ESRIusername,ldapstatus,ldapuid,ldapuidNumber,ldapchicagoID,ldapcn,ldapeduPersonPrimaryAffiliation,ldaptitle,ldapou,ldapucDepartment,ldapmail,ldaptelephoneNumber'
echo $ldapheader > ldap$today.txt
sed 1d $inputfile | while IFS=, read -a line
do
    echo ${line[0]}    
    ESRIusername=`echo ${line[0]} `
    cnetID=`echo $ESRIusername | sed -e 's/_UChicago//g'`
    #printf $cnetID
    ldapsearch -x -h ldap.uchicago.edu -b 'dc=uchicago,dc=edu' '(uid='$cnetID')' > ldif.txt
	#if [`cat ldif.txt | grep ':vpn:' | awk '{print $1}'` != "ucisMemberOf:"]; then
	if grep -q ":vpn:" ldif.txt; then 
		# parse the first HTML
		ldapstatus='active'		
		uid=`cat ldif.txt | grep "uid: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		uidNumber=`cat ldif.txt | grep "uidNumber: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		chicagoID=`cat ldif.txt | grep "chicagoID: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		cn=`cat ldif.txt | grep "cn: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		eduPersonPrimaryAffiliation=`cat ldif.txt | grep "eduPersonPrimaryAffiliation: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		title=`cat ldif.txt | grep "title: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		ou=`cat ldif.txt | grep "ou: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		ucDepartment=`cat ldif.txt | grep "ucDepartment: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		mail=`cat ldif.txt | grep "mail: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		telephoneNumber=`cat ldif.txt | grep "telephoneNumber: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		echo $cnetID","$ESRIusername","$ldapstatus","$uid","$uidNumber","$chicagoID","$cn","$eduPersonPrimaryAffiliation","$title","$ou","$ucDepartment","$mail","$telephoneNumber >> ldap$today.txt
	elif grep -q "uid: " ldif.txt; then
		ldapstatus='inactive'
		uid=`cat ldif.txt | grep "uid: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		uidNumber=`cat ldif.txt | grep "uidNumber: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		chicagoID=`cat ldif.txt | grep "chicagoID: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		cn=`cat ldif.txt | grep "cn: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		eduPersonPrimaryAffiliation=`cat ldif.txt | grep "eduPersonPrimaryAffiliation: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		title=`cat ldif.txt | grep "title: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		ou=`cat ldif.txt | grep "ou: " | sed -e "s/.*: //g" -e "s/,/;/g"`
		echo $cnetID","$ESRIusername","$ldapstatus","$uid","$uidNumber","$chicagoID","$cn","$eduPersonPrimaryAffiliation","$title","$ou",,," >> ldap$today.txt
	else
		ldapstatus='na'
		uid=""
		uidNumber=""
		chicagoID=""
		cn=""
		eduPersonPrimaryAffiliation=""
		title=""
		ou=""
		echo $cnetID","$ESRIusername","$ldapstatus","$uid","$uidNumber","$chicagoID","$cn","$eduPersonPrimaryAffiliation","$title","$ou",,," >> ldap$today.txt
	fi
done

########################################
# add Jeff's inactive list


# find the index number for cnetID from the previous joined file
IFS=, read -r -a vararray <<< `head -n 1 ldap$today.txt` #turn the header into an array
typeset -A assocarray #want to turn the array into an associative array
for ((i=0; i<${#vararray[@]}; ++i)) ; do
    printf ${vararray[i]}
    assocarray[${vararray[i]}]=$i
done
cnet_index=`echo ${assocarray['cnetID']}`
let cnet_index=${cnet_index}+1  #"sort" index starts at 1, not 0

#join the new info, sort first (skip the header)
sed 1d ldap$today.txt | sort -k $cnet_index,1nr -f >join1.txt
sed 1d inactive-cnet-2016-07-07.csv | sort -k 1,1nr -f >join2.txt
join -a1 -a2 -e "" -t, -1 $cnet_index -2 1 join1.txt join2.txt > joined_Jeff.csv

#add the header back
fullheader=$(head -n 1 ldap$today.txt )",Jefffullname,Jeffresult"
sed -i 1i$fullheader joined_Jeff.csv


########################################
# add the new output to the input file

sed 1d $inputfile | sort -k 1,1nr -f >join1.txt
sed 1d joined_Jeff.csv | sort -k 2,2nr -f >join2.txt
join -a1 -a2 -e " " -1 1 -2 2 -t, join1.txt join2.txt > joined_final.csv

#add the header back
newheader=`echo $fullheader | sed -e 's/ESRIusername,//g'`
finalfullheader=$(head -n 1 $inputfile)","$newheader
sed -i 1i$finalfullheader joined_final.csv
