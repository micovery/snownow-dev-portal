# Snow.Now - Developer Portal

![](images/developer-portal.png?raw=true "SnowNow Developer portal")

This repo contains a Dockerfile for building a container image for SnowNow's developer portal.
The container image contains the following components:  

* [Apache 2](https://httpd.apache.org/)
* [MariaDB 10](https://mariadb.com/)
* [Apigee Drupal8 Kickstart](https://www.drupal.org/project/apigee_devportal_kickstart)

The docker image is meant to be used for development or demonstration purposes.

## Usage

In order to use the docker image, run the following command:

```bash
 docker run --rm -it \
            --publish 7070:80 \
             --publish 7073:443 \
            --name snownow-dev-portal \
            micovery/snownow-dev-portal
```

Then, point your browser to http://localhost:9090

The default administrator credentials are:

```
username: admin@snownow.com
password: SuperSecret123!
``` 


## Inside the container

You acn go into a bash shell inside the container by running the following command:

```bash
 docker exec -it snownow-dev-portal bash
```

This will log you in as the `drupal` user. The Drupal installation is located in /drupal/project.

From the shell you can use `composer` to install Drupal modules, and `drush` to enable them.


## Build Prerequisites

  * bash (Linux shell)
  * [Docker (18 or newer)](https://www.docker.com/)
  

## Building it


If you want to build the docker image yourself, run.

Start the build

```bash
$ KICKSTART_VERSION=8.x-dev ./docker-build.sh
```

After this is done, you will see a new docker image tagged

```shell script
micovery/snownow-dev-portal
```

## Backing up the site's content

If you make content changes to the site on a container, you can back-up this information,
and rebuild the docker image so that it reflects the latest content.

To do this, use one of methods described below to back-up the site's information. 

### MySQL Backup
Then, you can take a SQL dump of the entire database. To do this use the following script:

```shell script
./backup-database.sh
```

This will go ahead overwrite the existing db.sql file over at `backup/db.sql`.

### Files Backup

If your added new images or files as part of your content changes, you need to keep track of 
the location where the new files ended up inside the docker container's file system. For most
file uploads this is going to be under `/drupal/project/web/sites/default/files`. Once you locate
the files, go ahead and create a matching structure  under `backup/sites`

### Config backup
In addition to create a database backup, you can backup configuration files as YAML. To do this, use
the following script:

```shell script
./backup-config.sh
```

This script will dump a bunch of YAML configuration files into the `/backup/config` directory.
It's likely you do not need all of them. Take a look at the files in that directory and
keep only the files that you want for specific modules. (delete the others)

## Pushing the image to container registry

First make sure to login to DockerHub
```shell script
docker login
```

Then, run the docker push command
```shell script
docker push micovery/snownow-dev-portal:latest
```

## Using self-signed certificates

The docker image listens on both HTTP, and HTTPS. By default, when the
container starts, it checks whether there is a `/apache-certs` directory in the fie system.

If the `/apache-certs` directory does not exist, then it goes ahead and creates it, and
generates the following certificate and key files:

```shell script
/apache-certs/cert.pem
/apache-certs/privkey.pem
/apache-certs/fullchain.pem
``` 

In this way, you can use the HTTPS endpoint without having to provide your own cert/key/chain files.

## Using your own certificate and key files

If you want to use your own certificate and key, you must mount a volume under the `/apache-certs` directory
with following files

```shell script
/apache-certs/cert.pem
/apache-certs/privkey.pem
/apache-certs/fullchain.pem
``` 

This will indicate to the container, to not generate it own self signed certificate and key.


## Bypassing Invalid Certificate Error Page

If you are using a self signed certificate, the browser will likely warn you that the site is unsafe.

There are different tricks to skip this warning page and proceed to the actual site. 

* For Chrome, see [this page](https://medium.com/@dblazeski/chrome-bypass-net-err-cert-invalid-for-development-daefae43eb12)

