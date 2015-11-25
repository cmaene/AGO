#!/bin/bash

# get the HTML doc with a form/post and save as html.txt
curl http://www.chicagopolice.org/ps/list.aspx > html1.txt

# make sure to download formfind.pl from: https://github.com/Chronic-Dev/curl/blob/master/perl/contrib/formfind
perl formfind.pl < html1.txt > form.txt

# find what form NAMEs are there
# cat form.txt | grep NAME=

# In the case of this prostitution arrests, I need the following variables
VIEWSTATE=`cat form.txt | grep __VIEWSTATE | awk -F'"' '{print $4;}'`
EVENTVALIDATION=`cat form.txt | grep __EVENTVALIDATION | awk -F'"' '{print $4;}'`
# ddDistrict="ALL"		# all Chicago Police Districts
# ddDayRange="30"		# past 30 days (max date range available)sc
# btnChange="Submit Change"	# form submit value

curl -d __EVENTTARGET="" -d __EVENTARGUMENT="" --data-urlencode __VIEWSTATE=$VIEWSTATE --data-urlencode \
__EVENTVALIDATION=$EVENTVALIDATION -d ddDistrict="ALL" -d ddDayRange="30" -d btnChange="Submit Change" \
http://www.chicagopolice.org/ps/list.aspx \
> html2.txt

## sed extracts "lblKey" header part
cat html2.txt \
| sed -n "/<span id=\"lblKey\"/,/<\/span>/p" \
| tr -d '\r\n' \
| sed -e 's/<span id=\"lblKey\">\(.*\)<\/span><\/TD>/\1/' -e 's/\&nbsp\;/ /g' -e 's/<BR>/,/g' \
      -e 's/[ /\(/\)]//g' -e 's/\s\+//g' -e 's/\(.*\),/\1/' -e's/^/ID,/' -e 's/$/\n/' \
> tableheader.txt

# process table content, get result table part only
cat html2.txt \
| sed -n "/src=\"GetImage.aspx/,/<\/table>/p" \
| sed -e 's/\t//g' -e 's/\(.*\),/\1/' -e 's/no=\([^"border]*\).*/IDNUM_\1/' -e 's/.*\(IDNUM_[0-9].*\)/\1/' \
      -e 's/<br>/,/g' \
| tr  -d '\r\n' \
| sed -e 's/<\/td><td>/\n/g' -e 's/<\/td><\/tr><\/table>/\n/g' -e 's/<\/td><\/tr><tr><td>/\n/g' \
      -e 's/<\/TD>//g' -e 's/\(.*\),/\1/' -e 's/,XX /,/g' -e '/[0-9]XX/s/XX/00/g' -e 's/IDNUM_//g' \
> tableobs.txt

# remove the last newline (character, 4 bytes)
truncate -s -1 tableobs.txt

# combine header and the observations
sed -n 'p' tableheader.txt tableobs.txt > prostitutionarrest.csv

# download image. Ex: http://www.chicagopolice.org/ps/GetImage.aspx?no=19222145
while IFS=, read -a line
do
    echo "ID is     : ${line[0]}"
    ID=${line[0]}
    curl -o image/ID_$ID.jpg http://www.chicagopolice.org/ps/GetImage.aspx?no=$ID
done < tableobs.txt

# download a token for the geocoding session - using ArcGIS online developer's geocode2 app credential:
curl 'https://www.arcgis.com/sharing/oauth2/token?client_id=***********&grant_type=client_credentials&client_secret=*************&expiration=7200&f=pjson' \
--insecure -s -o token.txt

# or alternatively, the following also does the same:
# grep extract the line that include "access_token"
TOKEN=`cat token.txt | grep "access_token" | awk '{print $2}' | sed -e 's/[:|,|"]//g'`

# cat tableheader.txt
# ID,NAME,SEXAGE,HOMEADDRESS,HOMECITY,ARRESTADDRESS,ARRESTDATEYMD,STATUTE,VEHICLEIMPOUNDEDYN
# 0  1    2      3           4        5             6             7       8

# touch output.txt
header=`cat tableheader.txt`
header=`echo $header"|homegeocoded|homex|homey|homescore|hometype|arrestgeocoded|arrestx|arresty|arrestscore|arresttype"`
echo $header > output.txt
i=1
while IFS=, read -a line
do
    input=`echo ${line[0]}"|"${line[1]}"|"${line[2]}"|"${line[3]}"|"${line[4]}"|"${line[5]}"|"${line[6]}"|"${line[7]}"|"${line[8]}"|"`
    homeaddress=`echo ${line[3]} | sed 's/ /+/g'`
    city=`echo ${line[4]} | sed 's/ /+/g'`
    homeaddress=$homeaddress+$city+"IL"
    wget 'https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/find?text='$homeaddress'&f=pjson&token='$TOKEN --no-check-certificate -O homegeocoded.txt
    geocoded1a=`cat homegeocoded.txt | grep "name" | sed -e 's/\<name\>//g' -e 's/[:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    geocoded1b=`cat homegeocoded.txt | grep '"x":' | sed -e 's/[x|:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    geocoded1c=`cat homegeocoded.txt | grep '"y":' | sed -e 's/[y|:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    geocoded1d=`cat homegeocoded.txt | grep "Score" | sed -e 's/[Score|:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    geocoded1e=`cat homegeocoded.txt | grep "Addr_Type" | sed -e 's/\<Addr_Type\>//g' -e 's/[:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    arrestaddress=`echo ${line[5]} | sed 's/ /+/g'`
    arrestaddress=$arrestaddress+"Chicago"+"IL"
    wget 'https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/find?text='$arrestaddress'&f=pjson&token='$TOKEN --no-check-certificate -O arrestgeocoded.txt
    geocoded2a=`cat arrestgeocoded.txt | grep "name" | sed -e 's/\<name\>//g' -e 's/[:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    geocoded2b=`cat arrestgeocoded.txt | grep '"x":' | sed -e 's/[x|:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    geocoded2c=`cat arrestgeocoded.txt | grep '"y":' | sed -e 's/[y|:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    geocoded2d=`cat arrestgeocoded.txt | grep "Score" | sed -e 's/[Score|:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    geocoded2e=`cat arrestgeocoded.txt | grep "Addr_Type" | sed -e 's/\<Addr_Type\>//g' -e 's/[:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    temp=`echo $geocoded1a"|"$geocoded1b"|"$geocoded1c"|"$geocoded1d"|"$geocoded1e"|"$geocoded2a"|"$geocoded2b"|"$geocoded2c"|"$geocoded2d"|"$geocoded2e`
    echo $input$temp >> output.txt
    i=$(($i+1))
done < tableobs.txt

