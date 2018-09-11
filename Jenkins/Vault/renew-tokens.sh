#!/bin/bash
# 
# Default TTL for token is 2764800 sec. (32 days)
# this script renews TTL ofr tokens to default value.
# Parameters are set via environmnt variables to let Jenkins call the script.
# Parameters are:
# ENV - environment. 
#   used to generate name of settings file: . ~/.vault/secret_${ENV}
# USER_2_RENEW:
#   username to renew the token. Can be set to ALL to renew all tokens storen under ops/tokens
#
# Pay attention to the output, as long as /ops/tokens is manually supported storage it is possible
# that it will hold tokens which are not exist in the database.

if [[ -f ~/.vault_secret/${ENV} ]]; then
  . ~/.vault_secret/${ENV}
else
  echo 'Vault environment must be passed as a parameter or provided environment is not supported'
  exit 1
fi

declare -a USERS
if [[ $USER_2_RENEW == 'ALL' ]]; then
  USERS=$(/usr/local/bin/vault list secret/ops/tokens/ | grep -v Keys | grep -v "\-\--" | grep .)
else
  USERS=$USER_2_RENEW
fi

for usr in ${USERS[@]}; do
  TOKEN=$(/usr/local/bin/vault read secret/ops/tokens/$usr | grep token | awk '{print $2}')
  echo "${usr} : ${TOKEN}"
  /usr/local/bin/vault token-lookup $TOKEN > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    creation_ttl=$(/usr/local/bin/vault token-lookup $TOKEN | grep creation_ttl | awk '{print $2}')

    # Vault auth/token mount has been finetuned with:
    # vault mount-tune -default-lease-ttl=2160h  -max-lease-ttl=43800h auth/token
    # otherwise refreshing it with ttl = creation_ttl doesn't work.
    # Explanation is fuzzy but can be found here:
    # https://www.vaultproject.io/docs/concepts/tokens.html
    # and here
    # https://github.com/hashicorp/vault/issues/1079
    /usr/local/bin/vault token-renew $TOKEN $creation_ttl
  else
    printf "\033[0;31m${usr} :  ${TOKEN} is in ops/tokens but does not exist\033[0m\n"
  fi
done
