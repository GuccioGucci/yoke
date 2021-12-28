#!/usr/bin/env bash

# This is intended to be manually executed once you need to prepare some fixture files.
# Please, fill REQUESTS (within EOL) with individual command you want to record and save to file.
# Of course, you need a valid AWS session in the terminal :)
# Once done, please remember to anonymize resources (eg: removing your personal AWS account ID)

source "${BASH_SOURCE%/*}/../common"

REQUESTS=$( cat <<EOL
ec2 describe-security-groups --filter Name=group-name,Values=foobar
EOL
)

while IFS= read -r request; do
    response_file="$( to_response_file "$request" )"
    echo "processing $request as $response_file"
    aws $request > "$response_file"
done <<< "$REQUESTS"