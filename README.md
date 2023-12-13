# Prestashop Test Lab

## Motivation

From time to time, I need to upgrade some Prestashop sites and it is, admitedly, a tedious work.

For me it is always faster to test locally and then, once everything works as expected, upload the changes to the hosting provider.

After typing the same commands twice, I decided to automate the process a bit, so I only had to execute one command to get everything ready faster and less prone to human error.

It's far from perfect and it's not 100% automated, still it reduces the need to repeat some commands more than once, so the lazy guy in me is satisfied :-).


## Vagrant

I use Vagrant + libvirt to create the virtual environment for the test lab.

You can, of course, use whatever virtualization technology you like; still, I feel Vagrant is a fast and easy way to get things done.

This is the `Vagranfile` used to deploy the test instance on my computer:

```
Vagrant.configure("2") do |config|
  config.vm.define "DOMAIN"
  config.vm.box = "generic/ubuntu2004"

  config.vm.provider :libvirt do |libvirt|
    libvirt.memory = 8192     # 8 GB RAM
    libvirt.cpus = 4          # 4 vCPUs
  end

  #config.vm.network "private_network", type: "dhcp"
  config.vm.network "private_network", type: "static", ip: "192.168.121.150"

  config.vm.provision "shell", path: "ps_bootstrap.sh", :args => "'DOMAIN'"
end
```

It will spin up a single Ubuntu 20.04 LTS image, with 4 vCPUs and 8 GB RAM - adjust as needed based on your resources.

Keep this in mind if you need to test the very latest version of Prestashop which most likely will require PHP 8.x to run, as it might be easier to spin up a Ubuntu 22.04 LTS image (or newer) than installing PHP 8.x on Ubuntu 20.04 LTS... choose your poison! :-) 

It will also assign the static IP address `192.168.121.150` to the VM.

You can also use DHCP if you prefer. Just uncomment the line for DHCP, and comment the one which defines the static IP, like this:

```
  config.vm.network "private_network", type: "dhcp"
  #config.vm.network "private_network", type: "static", ip: "192.168.121.150"
```

Suggestion: replace `DOMAIN` with something you might find more useful, like your real shop's domain name; e.g.: `my-shop.com` - this will be used to, among other things: generate self-signed SSL certificates and the Apache VirtualHost configuration.

Now you can run either `vagrant up` or `recreate_vm.sh` to get the test lab rolled out.


## ps_bootstrap.sh

This is the script that is called by Vagrant once the VM has been deployed and it does all the heavy lifting for you.

However, before deploying your VM with `vagrant up`, there are some variables that you will need to adjust in order to reflect your environment:

Set the Prestashop version that you want to install for your tests:
```
# PrestaShop version to install
ps_version=1.7.4.2
```

Set the PHP version needed to run the Prestashop version defined above:
```
# PHP version to install
# This blog offers a good overview on version compatibility:
# -> https://www.prestasoo.com/blog/prestashop-php-version
ps_php_version=7.4
```

The Test Lab creates 2 databases:
- the production/real database
- a decoy/temporary database

Set here the needed information to connect to the (local) production database:
```
# DB info
#
# Define values for your real DB (the one you will import once Prestashop is installed)
ps_real_db=[PROD_DB]
ps_real_db_user=[PROD_DB_USR]
ps_real_db_pass=[PROD_DB_PASSWD].
ps_real_db_prefix=[PROD_DB_PREFIX]                      # default is usually "ps_"
ps_real_db_sql_dump_file=[PROD_DB_SQL_DUMP_FILE]        # e.g.: myDB_dump.sql 
```
In case your DB prefix still is `ps_`, please define it so in `ps_real_db_prefix`.

These are dummy values for the temporary database. You may drop it once you have imported your data into the `ps_real_db`. 
```
# You don't need to modify these if you don't want to.
# We'll use this DB to get Prestashop installed. 
# It can be dropped later on after importing $ps_real_db
ps_decoy_db=prestashop
ps_decoy_db_user=prestauser
ps_decoy_db_pass="Passw0rd1"
```

The script will generate self-signed SSL-certificates for you. Please, fill out these variables to fit your needs:
```
# SSL certificate data - adjust as needed
ssl_country=XX                      # e.g.: CH
ssl_state=[STATE]                   # e.g.: Zurich
ssl_location=[LOCATION]             # e.g.: Zurich
ssl_org="[MY_ORGANIZATION]"         # e.g.: Umbrella Corp.
ssl_ou="[MY_OU]"                    # e.g.: Project Alice
ssl_cn=$ps_domain
```

I live in Switzerland, so I set my APT mirror to something nearer than the US.
Set yours according to where you live:
```
# Set your closest APT mirror (default: us, set to your country)
ps_apt_mirror=ch
```

Set your time zone; check the link in the comments for further info:
```
# Set your time-zone
# ->  https://www.php.net/manual/en/timezones.php for valid values
ps_timezone="Europe/Zurich"
```


## How to use this thing

At the risk of sounding biased: it's really easy (perhaps because I've done this several times already) and, for sure, it can be improved. Feel free to create a PR with your suggestions.

Once you have defined all the needed variables mentioned above, you can execute either `vagrant up` or use the `./recreate_vm.sh` script. If you use the latter, it will automatically ssh into the VM once it's created.

`bootstrap.sh` will download the Prestashop version you defined in `ps_version` and uncompress it for you under `/var/www/html` and it will also install Apache2.

I recommend you to edit your `/etc/hosts` and add an entry for your domain while you are testing:

`192.168.121.150  my-shop.com                www.my-shop.com      phpmyadmin.my-shop.com`

...so you can connect to it using your web browser as usual. Don't forget to remove/comment it once you're done and want to access the real website.

That IP address is defined in the `Vagrantfile` shown above:

` config.vm.network "private_network", type: "static", ip: "192.168.121.150" `

Once your Vagrant instance is up & running, you will need to upload:
- the latest MySQL/MariaDB dump
- the `img` directory (hint: create a ZIP file: `img.zip`)

After that, you can import your MySQL/MariaDB dump onto your `ps_real_db` using the `db_import.sh` script (see below) and update the contents of the `img` directory with the `refresh_img.sh` script (also see below).

Finally, you will need to update the DB connection info in `app/config/parameters.php`; use the `update_parameters.sh` script for that if you don't want to do it manually.

And you are now all set.


## Helper scripts

The following little scripts were created to make my life a bit easier after the VM was deployed. Perhaps they will help you too... They are very simple, take certain conditions for granted, and don't include any sanity checks (I might improve that though). 

I list them here for your reference:

### recreate_vm.sh

Sometimes you need to start your tests from scratch, this script will destroy your running Vagrant instance and create a fresh one based on the `Vagrantfile` defined above. 

It will NOT ask for confirmation. Use with care.


### create_db_and_user.sh

This script is generated by `bootstrap.sh` and placed under `/root` inside the Vagrant instance.

It is invoked by `bootstrap.sh` to generate all the DB users, DB passwords, and the DB themselves.


### db_import.sh

This script is generated by `bootstrap.sh` and placed under `/root` inside the Vagrant instance.

You can use it to import the MySQL/MariaDB dump file (e.g.: myDB_dump.sql) into your production DB.

You must upload the SQL file from your local PC first to your Vagrant instance.

e.g.: `vagrant upload myDB_dump.sql`

Reminder: the stuff you upload this way lands under `/home/vagrant`

### refresh_img.sh

This script is generated by `bootstrap.sh` and placed under `/root` inside the Vagrant instance.

It will remove the default `img` directory and replace it with the contents of `img.zip` that you must first upload to your Vagrant instance.

e.g.: `vagrant upload img.zip`

Reminder: the stuff you upload this way lands under `/home/vagrant`

### update_parameters.sh

This script is generated by `bootstrap.sh` and placed under `/root` inside the Vagrant instance.

It will take care of updating the DB connection settings in `app/config/parameters.php`.


## bugs

I'm totally aware that my scripts dream of perfection :-). If you find a bug, please raise an issue on GitHub and will take a look at it. 

Ideally, create a PR and submit your own bug fixes! :-) 


## disclaimer
I am providing this test lab kit to the Prestashop Community on an "AS IS" basis.

I will not be held responsible for any damage that its use or misuse may cause.
