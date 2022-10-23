# Description

This is docker image for Fusion Direcotry application. It is web control for LDAP.

https://www.fusiondirectory.org/en/

It's very old project.

# Configuration

## Ports

* 80 - веб интерфейс

-p 30080:80

## Volumes

* /etc/fusiondirectory - Каталог с настройками (файл fusiondirectory.conf)

-v conf_directory:/etc/fusiondirectory

## Environment variable

* PLUGINS - Список плагинов, через точку с запятой (";")
* LOCALES_ADD - Список локалей, которые должны быть добавлены (разделенные ";")
* LDAP_USER_CONFIG - dn пользователя под которым разрешено редактировать контекст cn=config
* LDAP_USER_CONFIG_PASS - пароль для этого пользователя
* LDAP_SERVER - адрес сервера

-e "PLUGINS=ssh;sudo;samba"

## Example

```bash
docker build -t shizacat/fd:15 .

docker run -d --name fd-test \
	-p 8045:80 \
	-v /home/countz/projects/docker-fusiondirectory/v4/conf:/etc/fusiondirectory \
	-e "PLUGINS=argonaut,systems;samba" \
	-e "LOCALES_ADD=en_US.UTF-8;ru_RU.UTF-8" \
	shizacat/fd:15
```

### Работа с fusiondirectory-insert-schema

docker exec -ti fd-test /bin/bash

option -o "-D cn=admin,cn=config -w password -H ldap://hostname.com/"

Path schemas:
 /var/www/fusiondirectory/contrib/openldap/

