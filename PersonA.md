4. [Person A] Create a client interface Web application.
[Person A] Create controllers, services, and Slim views for:
[Person A] a layout template with navigation bar (home/login/register or home/account/logout)
[Person A] a home page
[Person A] a login page
[Person A] an account overview page for logged in users
[Person A] Allow users to login using the login page.
[Person A] Use a service object call to 
authenticate the user with your API.
[Person A] Use cookie-based sessions to store the logged in user's username and other non-sensitive account information (e.g., email) between requests.
[Person A] Allow users to logout by deleting account information from session data in cookie.
[Person A] Be sure to use appropriate status codes on errors (e.g., login failed).

5. [Person A] Add flash messages for errors and notices.
[Person A] Setup the flash plugin for Roda.
[Person A] Add a flash message bar to your layout.slim – you may also 
render it from a separate file.
[Person A] Set appropriate class styles for :error and :notice.
[Person A] Provide flash notices for form errors and important 
transitions (e.g., login and unauthorized error).