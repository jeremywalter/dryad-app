
Salesforce API
===============


- There is no "service" account; everything must be accessed through a client
  account, so the client has to authorize access before you can get a token

To setup Salesforce for API use:
- create an app in Setup/Apps/App Manager
  - created it as a "connected app"
  - ensure OAuth is enabled
  - select the scope "Full Access" unless there is a reason to restrict it
- When viewing the app, the page will show the "consumer" ID and secret (which
  will be used as the OAUTH client_id and client_secret)
- Obtain a token for accessing a particular Salesforce account:
  - Go to your user profile settings
  - In "My Personal Information", choose "Reset My Security Token"

Dryad connects using the "Restforce" gem:
- https://github.com/restforce/restforce


Using Restforce in Ruby
-------------------------

```ruby
# Connect with Salesforce
@sf = Restforce.new(username: <REPLACE>,
    password: <REPLACE>,
	security_token: <REPLACE>,
	client_id: <REPLACE>,
	client_secret: <REPLACE>,
	api_version: '39.0')
@sf.authenticate!

# Some useful commands, get actual ID numbers from the Salesforce UI
@sf.user_info
@sf.find('Lead', '00Q5e000007HsfvEAC') 
@sf.find('Account', '0013h00000Ir8eHAAR')
sf_journals = @sf.query('select Id, Name, Type, Type_of_Journal_Sponsorship__c from Account')
sf_journals.first.Name
sf_journals.current_page
```		


Synchronizing between Dryad and Salesforce
------------------------------------------

To report on the correspondence between Dryad journal settings and Salesforce
journal settings:

```
rails journals:check_salesforce_sync
```

To clean up metadata in Salesforce associated with journals, add `DRY_RUN=false`
to the end of the above command.


Salesforce configuration
--------------------------

To create/edit fields in Salesforce objects:
- Setup
- Object Manager
- Select the type of object (e.g., "case")
- Fields and Relationships
