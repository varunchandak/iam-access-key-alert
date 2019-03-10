#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/snap/bin:"$PATH"
AWS_PROFILE="$1"
alias aws=''`which aws`' --profile '"$AWS_PROFILE"''
shopt -s expand_aliases

usage() {
        echo 'This script is used to send email alerts for ACCESS KEY and SECRET KEY notifications to the IAM users configured with email addresses.
Note:
- This is a custom script with `sendmail` AND `sendEmail` configured with SES.

Usage:
./script.sh <AWS_PROFILE>

Example:
./script.sh awsprofile'
}

if [ "$#" -ne 1 ]; then
        usage
else
        export SES_USERNAME=""
        export SES_PASSWORD=""

        # START Main Logic
        export ACCOUNT_ID="$(aws sts get-caller-identity --output text --query 'Account')"
        aws iam generate-credential-report
        aws iam get-credential-report --query 'Content' --output text | base64 --decode > full-credential-report.csv

        sendKeyAlert() {
                export IAMUSER="$1"
                export KEY_LIST="$(aws iam list-access-keys --user-name "$IAMUSER" --output text --query 'AccessKeyMetadata[].AccessKeyId' | tr -s '\t' ',' | sed 's/,/, /g')"
                export EMAILMESSAGE="$(echo -e 'Hello '"$IAMUSER"',\n\nYou are receiving this mail as you have 1 or more IAM Access Keys configured for your IAM Username (Access Keys: '"$KEY_LIST"'). As a part of mandatory security protocols and best practices, it is advised to change to Access Key/Secret Key in AWS console immediately. Failure to do so will result in Key Reset or access revoked.\n\nSign-in URL: https://'"$ACCOUNT_ID"'.signin.aws.amazon.com/console\n\n\nNote: You may receive multiple mails if you have more than 1 key configured.')"
                sendemail \
                        -o tls=yes \
                        -xu "$SES_USERNAME" \
                        -xp "$SES_PASSWORD" \
                        -s email-smtp.us-east-1.amazonaws.com:587 \
                        -f "<FROM_EMAIL_ADDRESS>" \
                        -t "$IAMUSER" \
                        -cc "<CC_EMAIL_ADDRESS_1>" "<CC_EMAIL_ADDRESS_2>" \
                        -bcc "<BCC_EMAIL_ADDRESS>" \
                        -u "IMPORTANT - AWS Access Key/Secret Key Rotation Alert (Account: $AWS_PROFILE | IAM User: $IAMUSER)" \
                        -m "$EMAILMESSAGE"
                sleep 2
        }

        ##################
        ## users having access key 1 and needs rotation > 90 days
        awk -F, '{print $1","$10}' full-credential-report.csv | grep -v -e 'N/A'$ -e no_information$ -e "access_key_[0-9]*.*"$ -e '<root' | awk -F, -vOFS=, 'NR=1{$2=substr($2,1,10)}1' > /tmp/password_details.csv
        IFS=','
        while read -r USER_NAME ACCESS_KEY_LAST_USE; do
                todate="$(date -d "$ACCESS_KEY_LAST_USE" +%s)"
                cond="$(date +%s)"
                AGE_TIME=$(echo "scale=1;($cond-$todate)/60/60/24" | bc -l);
                if (( $(echo "$AGE_TIME 90" | awk '{print ($1 > $2)}') )); then
                        sendKeyAlert "$USER_NAME"
                fi
        done < /tmp/password_details.csv | sort -t' ' -k5

        ## users having access key 2 and needs rotation > 90 days
        awk -F, '{print $1","$15}' full-credential-report.csv | grep -v -e 'N/A'$ -e no_information$ -e "access_key_[0-9]*.*"$ -e '<root' | awk -F, -vOFS=, 'NR=1{$2=substr($2,1,10)}1' > /tmp/password_details.csv
        IFS=','
        while read -r USER_NAME ACCESS_KEY_LAST_ROTATE; do
                todate="$(date -d "$ACCESS_KEY_LAST_ROTATE" +%s)"
                cond="$(date +%s)"
                AGE_TIME=$(echo "scale=1;($cond-$todate)/60/60/24" | bc -l);
                if (( $(echo "$AGE_TIME 90" | awk '{print ($1 > $2)}') )); then
                        sendKeyAlert "$USER_NAME"
                fi
        done < /tmp/password_details.csv | sort -t' ' -k5
        ###################
        # END Main Logic
        rm -rfv full-credential-report.csv /tmp/password_details.csv
fi
