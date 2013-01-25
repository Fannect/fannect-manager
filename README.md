# Fannect API
[![Build Status](https://secure.travis-ci.org/Fannect/fannect-mobileweb.png?branch=master)](https://travis-ci.org/Fannect/fannect-mobileweb)

This is the source for the Fannect login API.

# REST Schema
This is based on [this video](http://blog.apigee.com/detail/restful_api_design) by apigee

### `/v1/token`
* POST - retrieve `access_token` and `refresh_token` with user credentials
* PUT - retrieve fresh `access_token`  with valid `refresh_token`

### `/v1/users`
* POST - create new user
* 
```javascript
{
  "email": "testing@fannect.me",
  "first_name": "Test",
  "last_name": "er",
  "refresh_token": "7a3580abe4bd690a236d13d9276f5e0df5093241d74ba711d99121a0659f5506",
  "_id": "51021bd70f3d6f0000000001",
  "invites": [(0)],
  "team_profiles": [(0)],
  "friends": [(0)],
  "created_on": "2013-01-25T05:44:55.621Z",
  "access_token": "73001fb4fa0d57ddaf63bf3dfe859e34"
}
```
