# This script is used to send Access key rotation alerts to the IAM users configured with email addresses to login to AWS console.

## Usage:
```
./script.sh <AWS_PROFILE>
```

## Example:
```
./script.sh some-profile-name
```

## Notes:
- `FROM_ADDRESS` must be a SES verified email address, else the mailer will fail.
- This script assumes that the IAMUSER name is in email ID format.
- Install `sendEmail` on the linux box to send email.
- add SES SMTP credentials in the script to send email. `SES_USERNAME` and `SES_PASSWORD`
- This is a custom script with `sendmail` AND `sendEmail` configured with SES.
