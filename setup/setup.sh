# if terraform stuff exists 
    # get secrets from key vault
# else
    # new infrastructure deployment

# get secrets from key vault
    # use az cli to get secrets from KV
    # setup tf_vars file

# new infra deployment
    # create a sp
    # create backend resources
    # store secrets in KV?
    # setup tf_vars file