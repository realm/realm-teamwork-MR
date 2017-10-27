#!/bin/bash
read -r -p "This will remove all  Realms and data. Are you sure? [Y/n]" response

response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
    echo "Removing Realm files..."
    rm -rvf realm-object-server data DataLoaded.txt
    echo "Done."
fi


