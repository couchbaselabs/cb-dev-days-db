#!/bin/bash

#output commands (i.e. turn debug info on/off)
#set -x

#enable fg and bg commands
set -m

#run couchbase in the background so server can be configured
/entrypoint.sh couchbase-server &

sleep 15

echo "initializing cluster..."
couchbase-cli cluster-init -c $CB_HOST \
--cluster-name demo \
--cluster-username $CB_USER \
--cluster-password $CB_PASSWORD \
--cluster-ramsize 512 \
--cluster-index-ramsize 256 \
--cluster-fts-ramsize 256 \
--services data,index,query,fts

sleep 3

couchbase-cli server-list -c $CB_HOST -u $CB_USER -p $CB_PASSWORD
echo "cluster initialized.  URL:  $CB_URL"
sleep 3

#create bucket
couchbase-cli bucket-create -c $CB_URL \
--username $CB_USER \
--password $CB_PASSWORD \
--bucket $CB_BUCKET \
--bucket-type couchbase \
--bucket-ramsize 256

sleep 3

echo "loading bucket data..."
unzip /opt/couchbase/retailsample_data.zip -d /opt/couchbase

count=1
while [ $count -le 5 ]
do
    if [ -f /opt/couchbase/customers.json ]; then
        break
    fi
    sleep 3
    ((count++))

done

#add customer documents
echo "importing customer documents..."
/opt/couchbase/bin/cbimport json -c couchbase://${CB_HOST} \
-u $CB_USER \
-p $CB_PASSWORD \
-b $CB_BUCKET \
-d file:///opt/couchbase/customers.json \
-f list \
-g customer_%custId% \
-t 4

rm /opt/couchbase/customers.json

#add user documents
echo "importing user documents..."
/opt/couchbase/bin/cbimport json -c couchbase://${CB_HOST} \
-u $CB_USER \
-p $CB_PASSWORD \
-b $CB_BUCKET \
-d file:///opt/couchbase/users.json \
-f list \
-g user_%userId% \
-t 4

rm /opt/couchbase/users.json

#add order documents
echo "importing order documents..."
/opt/couchbase/bin/cbimport json -c couchbase://${CB_HOST} \
-u $CB_USER \
-p $CB_PASSWORD \
-b $CB_BUCKET \
-d file:///opt/couchbase/orders.json \
-f list \
-g order_%orderId% \
-t 4

rm /opt/couchbase/orders.json

#add product documents
echo "importing product documents..."
/opt/couchbase/bin/cbimport json -c couchbase://${CB_HOST} \
-u $CB_USER \
-p $CB_PASSWORD \
-b $CB_BUCKET \
-d file:///opt/couchbase/products.json \
-f list \
-g product_%prodId% \
-t 4

rm /opt/couchbase/products.json

echo "creating indexes..."
cbq -e couchbase://${CB_HOST} \
-u $CB_USER \
-p $CB_PASSWORD \
-f=/opt/couchbase/indexes.txt

echo "creating FTS index..."
curl -u $CB_USER:$CB_PASSWORD -XPUT http://$CB_HOST:8094/api/index/basic-search -H "Content-type:application/json" -d @/opt/couchbase/basic_search_idx.json

#resume couchbase job in the foreground
fg 1