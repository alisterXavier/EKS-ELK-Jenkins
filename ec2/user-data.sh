#!/bin/bash


# Update and install nginx
echo "Starting user data script" >> /tmp/userdata.log
yum update -y >> /tmp/userdata.log 2>&1
yum install -y nginx >> /tmp/userdata.log 2>&1
echo "NGINX installed" >> /tmp/userdata.log

# Get self-signed Certificate
echo "Generating self-signed certificate" >> /tmp/userdata.log
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/cert.key -out /etc/nginx/cert.crt -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=thunder.com" >> /tmp/userdata.log 2>&1
echo "Generated self-signed certificate" >> /tmp/userdata.log

# Set up nginx reverse proxy cognito -> opensearch
echo "Creating reverse proxy configuration" >> /tmp/userdata.log
cat <<EOL > /etc/nginx/conf.d/default.conf
  server {  
      listen 443;
      server_name \$host;
      rewrite ^/\$ https://\$host/_dashboards redirect;
      resolver 10.0.0.2 ipv6=off valid=5s;
      set \$domain_endpoint ${opensearch_domain};
      set \$cognito_host ${cognito_domain};

      ssl_certificate           /etc/nginx/cert.crt;
      ssl_certificate_key       /etc/nginx/cert.key;

      ssl on;
      ssl_session_cache  builtin:1000  shared:SSL:10m;
      ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
      ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
      ssl_prefer_server_ciphers on;

      location ^~ /_dashboards {
          # Forward requests to Dashboards
          proxy_pass https://\$domain_endpoint;

          # Handle redirects to Cognito
          proxy_redirect https://\$cognito_host https://\$host;

          # Handle redirects to Dashboards
          proxy_redirect https://\$domain_endpoint https://\$host;

          # Update cookie domain and path
          proxy_cookie_domain \$domain_endpoint \$host;
          proxy_cookie_path ~*^/\$ /_dashboards/;

          # Response buffer settings
          proxy_buffer_size 128k;
          proxy_buffers 4 256k;
          proxy_busy_buffers_size 256k;
      }

      location ~ \/(log|sign|fav|forgot|change|saml|oauth2|confirm) {
          # Forward requests to Cognito
          proxy_pass https://\$cognito_host;

          # Handle redirects to Dashboards
          proxy_redirect https://\$domain_endpoint https://\$host;

          # Handle redirects to Cognito
          proxy_redirect https://\$cognito_host https://\$host;

          proxy_cookie_domain \$cognito_host \$host;
      }
  }
EOL


echo "Created reverse proxy configuration" >> /tmp/userdata.log

# Restart and enable nginx
echo "Starting nginx service" >> /tmp/userdata.log
systemctl enable nginx && sudo systemctl start nginx >> /tmp/userdata.log 2>&1
echo "Started nginx service"