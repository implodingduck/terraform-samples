#!/bin/bash

APP_SERVICE_NAME=$(terraform output -raw app_service_name)
RESOURCE_GROUP_NAME=$(terraform output -raw resource_group_name)

echo $APP_SERVICE_NAME
echo $RESOURCE_GROUP_NAME

az webapp deploy \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --src-path app.zip