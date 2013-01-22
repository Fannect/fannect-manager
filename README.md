# Fannect API
[![Build Status](https://secure.travis-ci.org/Fannect/fannect-mobileweb.png?branch=master)](https://travis-ci.org/Fannect/fannect-mobileweb)

This is the source for the Fannect login API.

# REST Schema
This is based on [this video](http://blog.apigee.com/detail/restful_api_design) by apigee

### `/v1/token`
* POST - retrieve `access_token` and `refresh_token` with user credentials
* PUT - retrieve fresh `access_token`  with valid `refresh_token`
