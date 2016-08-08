#!/bin/bash
### Set Language
TEXTDOMAIN=virtualhost

### Set default parameters
action=$1
domain=$2
rootDir=$3
owner=$(who am i | awk '{print $1}')
sitesEnable='/etc/nginx/sites-enabled/'
sitesAvailable='/etc/nginx/sites-available/'
userDir='/var/www/'

if [ "$(whoami)" != 'root' ]; then
	echo $"You have no permission to run $0 as non-root user. Use sudo"
		exit 1;
fi

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
	then
		echo $"You need to prompt for action (create or delete) -- Lower-case only"
		exit 1;
fi

while [ "$domain" == "" ]
do
	echo -e $"Please provide domain. e.g.dev,staging"
	read domain
done

if [ "$rootDir" == "" ]; then
	rootDir=${domain//./}
fi

### if root dir starts with '/', don't use /var/www as default starting point
if [[ "$rootDir" =~ ^/ ]]; then
	userDir=''
fi

rootDir=$userDir$rootDir

if [ "$action" == 'create' ]
	then
		### check if domain already exists
		if [ -e $sitesAvailable$domain ]; then
			echo -e $"This domain already exists.\nPlease Try Another one"
			exit;
		fi

		### check if directory exists or not
		if ! [ -d $userDir$rootDir ]; then
			### create the directory
			mkdir $userDir$rootDir
			### give permission to root dir
			chmod 755 $userDir$rootDir
			### write test file in the new domain dir
			if ! echo "<?php echo phpinfo(); ?>" > $userDir$rootDir/phpinfo.php
				then
					echo $"ERROR: Not able to write in file $userDir/$rootDir/phpinfo.php. Please check permissions."
					exit;
			else
					echo $"Added content to $userDir$rootDir/phpinfo.php."
			fi
		fi
		
		### create let'sencrypt cert only.
		
		letsencrypt certonly —webroot -w $userDir$rootDir -d $domain

		### create virtual host rules file
		if ! echo "


#SSL HTTP2.0 Letsencrypt

server {
    
    listen 80 443 ssl http2;
    listen [::]:80;
    listen [::]:443;

    rewrite ^ https://$server_name$request_uri? permanent;
    server_name  $domain;
    root $userDir$rootDir;

# Add index.php to the list if you are using PHP

    index index.php index.html index.htm index.nginx-debian.html;    

    error_page  404              /404.html;
    error_page  500 502 503 504  /50x.html;

    access_log  /var/log/nginx/access.log;

    ssl_certificate      /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key  /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_session_timeout  1d;
    ssl_session_cache    shared:SSL:10m;
    ssl_session_tickets  off;
    ssl_stapling         on;
    ssl_stapling_verify  on;

# Generate with:
    # sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048
    ssl_dhparam  /etc/nginx/dhparam.pem;

    ssl_protocols              TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers  on;
    ssl_ciphers                'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';

    add_header  Strict-Transport-Security 'max-age=31536000; includeSubDomains';

    location / {
        index index.php;
         try_files $uri $uri/ /index.php;
    }

     location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar|woff)$ {
        expires    modified +1h;
        try_files  $uri =404;
    }


#PHP7.0 Configuration [ENABLED]

    location ~ \.php$ {

    #   include snippets/fastcgi-php.conf;
    #   fastcgi_pass unix:/var/run/php7.0-fpm.sock;

    try_files $uri =404;
        fastcgi_pass 127.0.0.1:9000;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_index index.php;
        include fastcgi_params;
    }

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    
    location ~ /\.ht {
        deny all;
    }

    location ~ /.well-known {
        allow all;
    }

}


		" > $sitesAvailable$domain
		then
			echo -e $"There is an ERROR create $domain file"
			exit;
		else
			echo -e $"\nNew Virtual Host Created\n"
		fi

		### Add domain in /etc/hosts
		if ! echo "127.0.0.1	$domain" >> /etc/hosts
			then
				echo $"ERROR: Not able write in /etc/hosts"
				exit;
		else
				echo -e $"Host added to /etc/hosts file \n"
		fi

		if [ "$owner" == "" ]; then
			chown -R $(whoami):www-data $userDir$rootDir
		else
			chown -R $owner:www-data $userDir$rootDir
		fi

		### enable website
		ln -s $sitesAvailable$domain $sitesEnable$domain

		### restart Nginx
		service nginx restart

		### show the finished message
		echo -e $"Complete! \nYou now have a new Virtual Host \nYour new host is: https://$domain \nAnd its located at $userDir$rootDir"
		exit;
	else
		### check whether domain already exists
		if ! [ -e $sitesAvailable$domain ]; then
			echo -e $"This domain dont exists.\nPlease Try Another one"
			exit;
		else
			### Delete domain in /etc/hosts
			newhost=${domain//./\\.}
			sed -i "/$newhost/d" /etc/hosts

			### disable website
			rm $sitesEnable$domain

			### restart Nginx
			service nginx restart

			### Delete virtual host rules files
			rm $sitesAvailable$domain
		fi

		### check if directory exists or not
		if [ -d $userDir$rootDir ]; then
			echo -e $"Delete host root directory ? (s/n)"
			read deldir

			if [ "$deldir" == 's' -o "$deldir" == 'S' ]; then
				### Delete the directory
				rm -rf $userDir$rootDir
				echo -e $"Directory deleted"
			else
				echo -e $"Host directory conserved"
			fi
		else
			echo -e $"Host directory not found. Ignored"
		fi

		### show the finished message
		echo -e $"Complete!\nYou just removed Virtual Host $domain"
		exit 0;
fi
