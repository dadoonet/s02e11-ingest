source .env.sh

# Utility functions
check_service () {
	echo -ne '\n'
	echo $1 $ELASTIC_VERSION must be available on $2
	echo -ne "Waiting for $1"

	until curl -u elastic:$ELASTIC_PASSWORD -s "$2" | grep "$3" > /dev/null; do
		  sleep 1
			echo -ne '.'
	done

	echo -ne '\n'
	echo $1 is now up.
}

# Curl Delete call Param 1 is the Full URL, Param 2 is optional text
# curl_delete "$ELASTICSEARCH_URL/foo*" "Fancy text"
# curl_delete "$ELASTICSEARCH_URL/foo*"
curl_delete () {
	if [ -z "$2" ] ; then
		echo "Calling DELETE $1"
	else 
	  echo $2
	fi
  curl -XDELETE "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' ; echo
}

# Curl Post call Param 1 is the Full URL, Param 2 is a json file, Param 3 is optional text
# 
curl_post () {
	if [ -z "$3" ] ; then
		echo "Calling POST $1"
	else 
	  echo $3
	fi
  curl -XPOST "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d"@$2" ; echo
}

# Curl Post call Param 1 is the Full URL, Param 2 is a json file, Param 3 is optional text
# 
curl_post_form () {
	if [ -z "$3" ] ; then
		echo "Calling POST FORM $1"
	else 
	  echo $3
	fi
  curl -XPOST "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' --form file="@$2" ; echo
}

# Curl Put call Param 1 is the Full URL, Param 2 is a json file, Param 3 is optional text
# 
curl_put () {
	if [ -z "$3" ] ; then
		echo "Calling PUT $1"
	else 
	  echo $3
	fi
  curl -XPUT "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d"@$2" ; echo
}

# Curl Get call Param 1 is the Full URL, Param 2 is optional text
# 
curl_get () {
	if [ -z "$2" ] ; then
		echo "Calling GET $1"
	else 
	  echo $2
	fi
  curl -XGET "$1" -u elastic:$ELASTIC_PASSWORD ; echo
}

DATASOURCE_DIR=$(pwd)/dataset

download_region () {
    export REGION=$1
    FILE=$DATASOURCE_DIR/bano-$REGION.csv
    URL=http://bano.openstreetmap.fr/data/bano-$REGION.csv
    # We import the region from openstreet map if not available yet
    if [ ! -e $FILE ] ; then
        echo "Fetching $FILE from $URL"
        wget $URL -P $DATASOURCE_DIR
    fi
}

# Start of the script
echo Installation script for Kibana Ingest Management demo with Elastic $ELASTIC_VERSION

echo "##################"
echo "### Pre-checks ###"
echo "##################"

if [ -z "$CLOUD_ID" ] ; then
	echo "We are running a local demo. If you did not start Elastic yet, please run:"
	echo "docker-compose up"
fi

check_service "Elasticsearch" "$ELASTICSEARCH_URL" "\"number\" : \"$ELASTIC_VERSION\""
check_service "Kibana" "$KIBANA_URL/app/home#/" "<title>Elastic</title>"

echo -ne '\n'
echo "#######################"
echo "### Prepare Dataset ###"
echo "#######################"
echo -ne '\n'

curl_delete "$ELASTICSEARCH_URL/demo_csv*"
curl_delete "$ELASTICSEARCH_URL/_ingest/pipeline/bano"

if [ ! -e $DATASOURCE_DIR ] ; then
    echo "Creating $DATASOURCE_DIR dir"
    mkdir $DATASOURCE_DIR
fi

# Download a CSV file
download_region 95

# Transform the X first lines to a bulk request
echo "Creating the data. Please wait..."
head -10000 $DATASOURCE_DIR/bano-95.csv | while read -r line; do NOW=$(date +"%Y-%m-%dT%T") ; printf "{ \"index\" : {}}\n{\"@timestamp\":\"$NOW\", \"message\":\"$line\"}\n"; done > $DATASOURCE_DIR/bulk-95.ndjson

echo "Injecting the data. Please wait..."
curl -XPOST "$ELASTICSEARCH_URL/demo_csv/_bulk" -s -u elastic:$ELASTIC_PASSWORD -H 'Content-Type: application/x-ndjson' --data-binary "@$DATASOURCE_DIR/bulk-95.ndjson" | jq '{took: .took, errors: .errors}' ; echo

#echo -ne '\n'
#echo "###############################"
#echo "### Install Kibana Elements ###"
#echo "###############################"
#echo -ne '\n'

echo -ne '\n'
echo "#############################"
echo "### Install Canvas Slides ###"
echo "#############################"
echo -ne '\n'

curl_post_form "$KIBANA_URL/api/saved_objects/_import?overwrite=true" "kibana-config/canvas.ndjson"

echo -ne '\n'
echo "#####################"
echo "### Demo is ready ###"
echo "#####################"
echo -ne '\n'

open "$KIBANA_URL/app/canvas/"
open "$KIBANA_URL/app/dev_tools/"
open "$KIBANA_URL/app/management/ingest/ingest_pipelines/"

echo "If not yet there, paste the following script in Dev Tools:"
cat elasticsearch-config/devtools-script.json
echo -ne '\n'

