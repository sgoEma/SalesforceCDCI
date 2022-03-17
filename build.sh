#!/bin/bash -ex

# Parameters
DECRYPTION_KEY=$1
DECRYPTION_IV=$2
SOURCE_BRANCH=$3
TARGET_BRANCH=$4
INSTANCE_URL=$5
CONSUMER_KEY=$6
USER_NAME=$7
VALIDATE_ONLY=$8


# Static Values
CLI_URL="https://developer.salesforce.com/media/salesforce-cli/sfdx-linux-amd64.tar.xz"
#Create sfdx directory
mkdir sfdx
#Install Salesforce CLI
wget -qO- $CLI_URL | tar xJ -C sfdx --strip-components 1
"./sfdx/install"
sfdx --version
sfdx plugins --core
#Decrypt server key
openssl enc -nosalt -aes-256-cbc -d -in assets/server.key.enc -out assets/server.key -base64 -K $DECRYPTION_KEY -iv $DECRYPTION_IV


#Get differences between branches
DELTA=$(git --no-pager diff --name-status origin/$TARGET_BRANCH origin/$SOURCE_BRANCH)
package=""
destructive=""
while read line; do
	vars=($line)
	if [[ "${vars[1]}" == "force-app"* ]]; then
		if [[ "${vars[0]}" == "R"* ]]; then
			package="${package}${package:+,}${vars[2]}"
			destructive="${destructive}${destructive:+,}${vars[1]}"
    	elif [ "${vars[0]}" = "D" ]; then
	    	destructive="${destructive}${destructive:+,}${vars[1]} ${vars[2]} ${vars[3]} ${vars[4]} ${vars[5]}"
	   	else
	   		package="${package}${package:+,}${vars[1]} ${vars[2]} ${vars[3]} ${vars[4]} ${vars[5]}"
	 	fi
	fi
done <<< "$DELTA"
echo " PC package:: $package"
echo " PC destructive:: $destructive"

if [[ ! -z "$package" ]]; then
	#Authorize target org
	sfdx auth:jwt:grant --instanceurl $INSTANCE_URL --clientid $CONSUMER_KEY --jwtkeyfile assets/server.key --username $USER_NAME --setalias ORGALIAS

	#Deploy to target deployment org and run unit tests
	sfdx force:source:deploy -u ORGALIAS -p "$package" -l RunLocalTests $VALIDATE_ONLY
fi