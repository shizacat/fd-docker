#!/bin/bash

FD_HOME="/var/www/fusiondirectory"
PLUGINS_FOLDER="/fusiondirectory-plugins"


# Копирование и создание директории под плагин
# $1 - plugin directory
# $2 - destinct directory
function create_and_copy_plugin_dir {
	if [[ ! -d $1 ]]; then
		return
	fi
	mkdir -p $2
	cp -R ${1}* $2
}

# install plugin process
# $1 - name of plugin
function install_plugin {
	NAME=$1
	if [[ -d "${PLUGINS_FOLDER}/${NAME}" ]]; then
		# cd "${PLUGINS_FOLDER}/${NAME}"

		# copy addons into plugins
		create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/addons/" "${FD_HOME}/plugins/addons/"

		# copy admin into plugins
		create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/admin/" "${FD_HOME}/plugins/admin/"

		# copy personal into plugins
		create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/personal/" "${FD_HOME}/plugins/personal/"

		# copy extra HTML and images
		# This line not works. Copy from fusiondirectory-setup
		# create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/html/" "${FD_HOME}/html/plugins/${NAME}"
		create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/html/" "${FD_HOME}/html/"

		# copy contrib
		create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/contrib/" "${FD_HOME}/doc/contrib/${NAME}"

		# copy config
		create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/config/" "${FD_HOME}/plugins/config/"

		# copy ldap schema
		create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/contrib/openldap/" "${FD_HOME}/contrib/openldap/"

		# copy includes
		create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/include/" "${FD_HOME}/include/"

		# copy etc FIXME !!! not right all files goes now to /var/cache/fusiondirectory/plugin
		#my $files_dirs_copied = rcopy($plugin_path."/etc/*", $vars{fd_config_dir});

		# copy the locales
		create_and_copy_plugin_dir "${PLUGINS_FOLDER}/${NAME}/locale/" "${FD_HOME}/locale/plugins/${NAME}"

	else
		echo "Plugin ${NAME}, not found."
	fi

	#finally update FusionDirectory's class.cache and locales
	fusiondirectory-setup --update-cache
	fusiondirectory-setup --update-locales
}

if [ ! -f /first_run ]; then

	touch /first_run

	# Gen locales
	IFS=";" read -ra LG <<< "$LOCALES_ADD"
	for x in "${LG[@]}"; do
		sed -i "s/^# ${x}*/${x}/" /etc/locale.gen
	done
	/usr/sbin/locale-gen

	IFS=';' read -ra PLUGIN_NAME <<< "$PLUGINS"
	for i in "${PLUGIN_NAME[@]}"; do
		install_plugin ${i}
	done

	chown www-data:www-data -R ${FD_HOME}
	fusiondirectory-setup --yes --check-directories --update-cache --update-locales
fi

apache2-foreground