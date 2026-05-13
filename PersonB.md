1. [Person B] Update API routing Structure (optional).
[Person B] Split your controller into multiple files if it’s getting too long.
[Person B] Use the multi_route plugin for Roda to dispatch requests to 
the right routing block.

2. [Person B] Add a POST route to Web API to authenticate credentials.
[Person B] e.g., POST '/api/v1/auth/authentication'
[Person B] If username/password is correct, return JSONified user 
information.
[Person B] Account ID, username, email, and roles at a minimum.
[Person B] Otherwise, return a 403 error code with a json message body.

3. [Person B] Require SSL connections to Web API.
[Person B] Check protocol schema for incoming requests.
[Person B] Block non-secure requests for production (HTTP).