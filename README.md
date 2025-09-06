# hello world client side leptos build and deply setup

process:
- get the hello world working locally
- get the code to compile on github actions
- copy the built files to the server using scp from github actions
  - create a new keypair for ssh
  - add private keys as a secrets for github actions
  - put the public key in server's known keys
- make the server deploy ready
  - install nginx
  - set up the nginx config to properly host the copied files
