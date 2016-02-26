#!/usr/bin/python  # version 2.7 - to make it work for 3, change "print" statement type
'''
for issues, please contact: cmaene@uchicago.edu

# usage note: 1st argument: input CSV file name
usage note: 2nd argument: geocoding address field - eg. projectaddress (street address field)
usage note: 3rd argument: (optional) supplemental geocoding address field - city (city name field)
usage note: 4th argument: (optional) supplemental geocoding address field - state (state name field)
usage note: 5th argument: (optional) supplemental geocoding address field

# usage examples
python sample.csv projectaddress city state

output is a new csv file: (input filename)_geocoded.(input file extension)
'''
import os, sys, json, csv, requests

# download a token for the geocoding session - using ArcGIS online developer's app credential:
token_j = requests.post('https://www.arcgis.com/sharing/rest/oauth2/token/', params={
  'f': 'json',
  'client_id': 'jqtPzyhvtRpHkAvj',
  'client_secret': '57b90a07e71d45a08eb689594bc41e67',
  'grant_type': 'client_credentials',
  'expiration': '20160'
})
token = token_j.json()['access_token']

# define what the delimiter will be, eg: ',' (comma)  '\t' (tab) '|' (pipe)
delimit = ','
''' # if we want to assume the delimiter based on the extension name:
    extension = os.path.splitext(os.path.basename(sys.argv[1]))[1]
    if extension == '.csv':
        delimit = ','
    elif extension == '.txt':
        delimit = '\t'
    else:
        delimit = ','
'''
# list of variable names we save from the ArcGIS online geocoder
# ref: https://developers.arcgis.com/rest/geocode/api-reference/geocoding-service-output.htm
geocoded_vars = ['g_address','g_x','g_y','g_score','g_addr_type']

def main():
    inputfname = os.path.splitext(os.path.basename(sys.argv[1]))[0]
    extension  = os.path.splitext(os.path.basename(sys.argv[1]))[1]
    with open(sys.argv[1],'rt') as f:
        originalf = csv.reader(f, delimiter=delimit)
        inputf = list(originalf) # convert csv input to list
        totaln = len(inputf)-1
        ffname = inputf[0] # collect names of columns/vars
        ffname.append('g_input_address')
        # add names for geocoding result vars
        for var in geocoded_vars:
            ffname.append(var)
        # loop through the list (originally csv), collect info and send to a geocoder
        rownum = 0
        cnterror = 0	
        for row in inputf:
            if rownum == 0:
                row = ffname # the first row is header/names of columns
            else:
                geocodeinput = row[ffname.index(sys.argv[2])] # address field has to be in the first column
                geocodeinput = geocodeinput.replace(":"," ")  # our input has : (colon) which isn't good for URL
                if (len(sys.argv) > 3 and row[ffname.index(sys.argv[3])] != ""):    # 2nd  optional address field
                    geocodeinput = geocodeinput + ", "+ row[ffname.index(sys.argv[3])]
                if (len(sys.argv) > 4 and row[ffname.index(sys.argv[4])] != ""):    # 3rd optional address field
                    geocodeinput = geocodeinput + ", "+ row[ffname.index(sys.argv[4])]	        
                if (len(sys.argv) > 5 and row[ffname.index(sys.argv[5])] != ""):    # 4th optional address field
                    geocodeinput = geocodeinput + ", "+ row[ffname.index(sys.argv[5])]
                row.append(geocodeinput) # keep address/location string to be geocoded
                #geocodeinput = geocodeinput.replace(" ","%20") # white space is disliked by urllib2 but ok with requests
                try:
                    geocoded = requests.post('https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/find/', params={
                      'text': geocodeinput,
                      'f': 'json',
                      'token': token
                    })
                    row.append(geocoded.json()['locations'][0]['name'])				        # geocoded address
                    row.append(geocoded.json()['locations'][0]['feature']['geometry']['x']) 		# X/long
                    row.append(geocoded.json()['locations'][0]['feature']['geometry']['y'])		# Y/lat
                    row.append(geocoded.json()['locations'][0]['feature']['attributes']['Score']) 	# geocoding score, just in case
                    row.append(geocoded.json()['locations'][0]['feature']['attributes']['Addr_Type']) 	# geocoding type
                    print(' geocoding '+str(rownum)+' of '+str(totaln)) # tell the progress..
                except:
                    for var in geocoded_vars:
                        row.append('')
                    print(' geocoding '+str(rownum)+' of '+str(totaln)+' - unsuccessful - sorry!')
                    cnterror += 1
                    pass
            rownum += 1
        ratesuccess=round((rownum-cnterror-1)/float(totaln)*100,1)
        print('Done! '+str(rownum-cnterror-1)+' cases were successfully geocoded ('+str(ratesuccess)+'% success)')

	# save the result/updated list in CSV format
        with open(inputfname+'_geocoded'+extension, 'w') as f2:  
            w = csv.writer(f2, delimiter=delimit)
            for row in inputf:
                w.writerow(row)
        file.close

# =============================
if __name__ == '__main__':
    main()
'''
    import time
    start_time = time.time()
    main()
    print("--- %s seconds ---" % (time.time() - start_time))
'''
