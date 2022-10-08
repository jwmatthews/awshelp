#!/usr/bin/env python
# 
# See for more info 
# - https://pyshark.com/google-sheets-api-using-python/
# - https://www.twilio.com/blog/2017/02/an-easy-way-to-read-and-write-to-a-google-spreadsheet-in-python.html

import json
import gspread
import sys
from oauth2client.service_account import ServiceAccountCredentials

# Need to change url 
#url = "https://docs.google.com/spreadsheets/d/1l9gT1ewSZ2bcm3IxjDBve5BOnjsXMAUn1CxIgFhqgDA/edit#gid=0"

scope = ['https://spreadsheets.google.com/feeds']
creds = ServiceAccountCredentials.from_json_keyfile_name('google_client_secret.json', scope)
client = gspread.authorize(creds)
gsheet = client.open_by_url(url)

wsheet = gsheet.worksheet("Instances")

# Extract and print all of the values
print(wsheet.get_all_values())

wsheet.clear()
wsheet.update("B1", "Instance DNS")
wsheet.update("C1", "Reserved By")

# Open json file
import json
inventoryfile = open('inventory.json' , 'r')
rawdata = inventoryfile.read()
inv_json = json.loads(rawdata)


if "aws_ec2" not in inv_json:
    print("Please check inventory, don't see hosts under 'aws_ec2'")
    sys.exit(1)

index = 2
for host in inv_json["aws_ec2"]["hosts"]:
    cell = "B%s" % index
    wsheet.update(cell, host)
    index += 1
