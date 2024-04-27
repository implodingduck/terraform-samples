#!/bin/bash

APP_SERVICE_NAME=$(terraform output -raw app_service_name)

for i in $(seq 0 100);
do
    curl https://$APP_SERVICE_NAME.azurewebsites.net/
done
