#!/bin/bash

today=`date +"%m%d%y"`

# -------------------------------------------------------
# Chicago prostitution arrest website scraping
# -------------------------------------------------------

# get the HTML doc with a form/post and save as html.txt
curl http://www.chicagopolice.org/ps/list.aspx > html1.txt

# make sure to download formfind.pl from: https://github.com/Chronic-Dev/curl/blob/master/perl/contrib/formfind
perl formfind.pl < html1.txt > form.txt

# cat form.txt | grep NAME=  # find what form NAMEs are there

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
    ID=${line[0]}
    curl -o image/ID_$ID.jpg http://www.chicagopolice.org/ps/GetImage.aspx?no=$ID
done < tableobs.txt

# -------------------------------------------------------
# Geocoding and routing/travel time/distance calculation
# -------------------------------------------------------

# download a token for the geocoding session - using ArcGIS online developer's geocode2 app credential:
# expiration max 20160 minutes (2 weeks)
curl 'https://www.arcgis.com/sharing/rest/oauth2/token?client_id=*********&grant_type=client_credentials&client_secret=*********&expiration=20160&f=pjson' \
--insecure -s -o token.txt

# grep extract the line that include "access_token"
TOKEN=`cat token.txt | grep "access_token" | awk '{print $2}' | sed -e 's/[:|,|"]//g'`

# cat tableheader.txt
# ID,NAME,SEXAGE,HOMEADDRESS,HOMECITY,ARRESTADDRESS,ARRESTDATEYMD,STATUTE,VEHICLEIMPOUNDEDYN
# 0  1    2      3           4        5             6             7       8

# touch output$today.txt
header=`cat tableheader.txt`
header=`echo $header"|homegeocoded|homex|homey|homegeocscore|homegeoctype|arrestgeocoded|arrestx|arresty|arrestgeocscore|arrestgeoctype|traveltimemin|traveldistmile"`
echo $header > output$today.txt
while IFS=, read -a line
do
    input=`echo ${line[0]}"|"${line[1]}"|"${line[2]}"|"${line[3]}"|"${line[4]}"|"${line[5]}"|"${line[6]}"|"${line[7]}"|"${line[8]}"|"`
    home=`echo ${line[3]} | sed 's/ /+/g'`
    arrest=`echo ${line[5]} | sed 's/ /+/g'`
    city=`echo ${line[4]} | sed 's/ /+/g'`
    home=$home+$city+"IL"
    arrest=$arrest+"Chicago"+"IL"
    typeset -A locations           # loudly declare/create an associative array
    #locations[home]=`echo $home`; locations[arrest]=`echo $arrest`   # one way of doing associative array assignment
    locations=(                    # this is a compound assignment
        [home]=`echo $home`
        [arrest]=`echo $arrest`
    )
    for loc in "${!locations[@]}"  # geocode twice for home and arrest locations, enumerate all indices (home/arrest)
    do
        address="${locations[$loc]}"
        curl 'https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/find?text='$address'&f=pjson&token='$TOKEN --insecure -s -o $loc.txt
        # dynamic/looping assignment is tricky - needed to loudly declare them, typeset for multiple words with space, eval for one word content
        typeset geoc1$loc="`cat $loc.txt | grep "name" | sed -e 's/\<name\>//g' -e 's/[:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`"
        eval geoc2$loc=`cat $loc.txt | grep '"x":' | sed -e 's/[x|:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
        eval geoc3$loc=`cat $loc.txt | grep '"y":' | sed -e 's/[y|:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
        eval geoc4$loc=`cat $loc.txt | grep "Score" | sed -e 's/[Score|:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
        eval geoc5$loc=`cat $loc.txt | grep "Addr_Type" | sed -e 's/\<Addr_Type\>//g' -e 's/[:|"|,]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    done
    curl 'https://route.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World/solve?stops='$geoc2home','$geoc3home';'$geoc2arrest','$geoc3arrest'&f=pjson&token='$TOKEN --insecure -s -o routing.txt
    routing1=`cat routing.txt | grep Total_TravelTime | grep -o '[0-9]*\.[0-9]*'`
    routing2=`cat routing.txt | grep Total_Miles | grep -o '[0-9]*\.[0-9]*'`
    routing1=`printf %.0f $routing1`  # minutes: round-up to integer minute
    routing2=`printf %.1f $routing2`  # miles: round-up to the first decimal
    temp=`echo $geoc1home"|"$geoc2home"|"$geoc3home"|"$geoc4home"|"$geoc5home"|"$geoc1arrest"|"$geoc2arrest"|"$geoc3arrest"|"$geoc4arrest"|"$geoc5arrest"|"$routing1"|"$routing2`
    echo $input$temp >> output$today.txt
done < tableobs.txt
