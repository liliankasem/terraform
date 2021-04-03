#!/bin/bash

SUBSCRIPTION_ID=

az login

az account set --subscription="SUBSCRIPTION_ID"

az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION_ID"