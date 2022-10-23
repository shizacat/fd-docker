#!/usr/bin/python
# -*- coding: utf-8 -*-

# Replace - fusiondirectory-insert-schema


import ldap.modlist as modlist
import ldap
import ldif
import os
import re
import sys
import argparse

import xml.etree.ElementTree as ET


LDAP_SERVER = None
LDAP_USER_CONFIG_DN = None
LDAP_USER_CONFIG_PASS = None

CORE_BASE_PATH_SCHEMES='/var/www/fusiondirectory/contrib/openldap'


# https://github.com/fusiondirectory/schema2ldif/blob/master/bin/schema2ldif
# Dependence: os, re
# Exception: ValueError
# input - file schema
# output - It is new ldif file, where will be written data
def schema2ldif(input, output, cn='', branch="cn=schema,cn=config"):
	
	if not os.path.isfile(input):
		raise ValueError('Не найден входной файл схемы')

	if cn == '':
		cn = os.path.split(input)[1]
		cn = cn.split(".")[0]

	with open(input, 'r') as schema_file, open(output, 'w') as file_ldif:

		file_ldif.write( "dn: cn=%s,%s\n" % (cn, branch))
		file_ldif.write( "objectClass: olcSchemaConfig\n")
		file_ldif.write( "cn: %s\n" % (cn))

		for line in schema_file:
			# Оставляем коментарии в файле
			# Пустрые строки означают конец записи и должны быть или законментированы (#) или удалены
			# Ключевые слова должны быть преобразованы
			#     objectIdentifier -> olcObjectIdentifier:
			#     objectClass -> olcObjectClasses:
			#     attributeType -> olcAttributeTypes:
			line = line.rstrip()

			if line == '':
				continue
			elif re.match('^\s*#', line):
				file_ldif.write( line)
				file_ldif.write( "\n")
			else:
				line = re.sub('^\s+', '  ', line)
				line = re.sub('^objectidentifier', 'olcObjectIdentifier:', line)
				line = re.sub('^attributetype', 'olcAttributeTypes:', line)
				line = re.sub('^objectclass', 'olcObjectClasses:', line)

				file_ldif.write( line)
				file_ldif.write( "\n")

# try:
# 	schema2ldif('../mail-fd.schema', 'mail-fd.ldif')
# except ValueError as e:
# 	print '[E]', e

def schema_insert(input):
	temp_file = 'temp.ldif'

	if not os.path.isfile(input):
		raise ValueError('Не найден входной файл схемы')

	fmt_of_file = os.path.split(input)[1].split(".")[-1].lower()

	if fmt_of_file == 'schema':
		schema2ldif(input, temp_file)
		input = temp_file
		fmt_of_file = 'ldif'

	if not fmt_of_file == 'ldif':
		raise ValueError('Не известный формат файла')

	try:
		con = ldap.initialize(LDAP_SERVER)
		con.bind_s( LDAP_USER_CONFIG_DN, LDAP_USER_CONFIG_PASS)

		with open(input, 'r') as file_ldif:
			for dn, entry in ldif.ParseLDIF(file_ldif):

				if schema_check_exist(entry['cn'][0]):
					raise ValueError("Схема '%s' уже существует" % entry['cn'][0])

				add_rec = [ (key, entry[key]) for key in entry.keys() ]

				# add_modlist = ldap.modlist.addModlist(entry)
				con.add_s(dn, add_rec)
	except ldap.LDAPError, e:
		raise ValueError(e)

	return

# Не пригодилась
# Аналог - modifyModlist
def ModifyListMy(old, new):
	res = []

	r = set(old.keys()) & set(new.keys())	# replace
	d = set(old.keys()) - set(new.keys())	# delete
	a = set(new.keys()) - set(old.keys())	# add

	for k in r:
		res.append( (ldap.MOD_REPLACE, k, new[k]) )

	for k in d:
		res.append( (ldap.MOD_DELETE, k, None) )

	for k in a:
		res.append( (ldap.MOD_ADD, k, new[k]) )

	return res

def schema_modify(input):
	temp_file = 'temp.ldif'

	if not os.path.isfile(input):
		raise ValueError('Не найден входной файл схемы')

	fmt_of_file = os.path.split(input)[1].split(".")[-1].lower()

	if fmt_of_file == 'schema':
		schema2ldif(input, temp_file)
		input = temp_file
		fmt_of_file = 'ldif'

	if not fmt_of_file == 'ldif':
		raise ValueError('Не известный формат файла')

	try:
		con = ldap.initialize(LDAP_SERVER)
		con.bind_s( LDAP_USER_CONFIG_DN, LDAP_USER_CONFIG_PASS)

		with open(input, 'r') as file_ldif:
			for dn, entry in ldif.ParseLDIF(file_ldif):

				if not schema_check_exist(entry['cn'][0]):
					raise ValueError("Схема '%s' не найдена" % entry['cn'][0])

				res = con.search_s( "cn=schema,cn=config", ldap.SCOPE_SUBTREE, '(&(objectClass=olcSchemaConfig)(cn=*%s))' % (entry['cn'][0]))
				if not res:
					raise ValueError("Записи для cn: '%s' не найдены" % entry['cn'][0])

				l = modlist.modifyModlist(res[0][1], entry, ignore_attr_types=['cn'])
				# l = ModifyListMy(res[0][1], entry)

				con.modify_s( res[0][0], l)
	except ldap.LDAPError, e:
		raise ValueError(e)

	return


# return: boolean
def schema_check_exist(schema):
	return schema in schema_list()

# return: list of schemes
def schema_list():
	base_dn="cn=schema,cn=config"

	res = []

	con = ldap.initialize(LDAP_SERVER)

	try:
		con.bind_s( LDAP_USER_CONFIG_DN, LDAP_USER_CONFIG_PASS)

		l = con.search_s( base_dn, ldap.SCOPE_ONELEVEL, '(objectClass=olcSchemaConfig)', ['cn'])
		res = [ re.sub('{.*}', '', entry['cn'][0]) for dn, entry in l]
	except ldap.LDAPError, e:
		raise ValueError(e)

	return res


def createParse():
	parser = argparse.ArgumentParser()
	parser.add_argument('-l', '--list', action='store_const', const=True, help='list inserted schemas')
	parser.add_argument('-i', '--insert', help='specify the schemas to insert')
	parser.add_argument('-m', '--modify', help='specify the schemas for modify exising inserted')

	return parser

if __name__ == '__main__':
	parser = createParse()
	namespace = parser.parse_args()

	# Config
	if os.path.isfile('/etc/fusiondirectory/fusiondirectory.conf'):
		tree = ET.parse('/etc/fusiondirectory/fusiondirectory.conf')
		root = tree.getroot()
		for ref in root.iter('referral'):
			LDAP_SERVER = "/".join( ref.attrib['URI'].split('/')[0:-1])
	else:
		if 'LDAP_SERVER' in os.environ.keys():
			LDAP_SERVER = os.environ['LDAP_SERVER']
		else:
			print('Ошибка. Не могу найти адрес сервера Ldap.')
			sys.exit(-1)

	if 'LDAP_USER_CONFIG' in os.environ.keys() and 'LDAP_USER_CONFIG_PASS' in os.environ.keys():
		LDAP_USER_CONFIG_DN = os.environ['LDAP_USER_CONFIG']
		LDAP_USER_CONFIG_PASS = os.environ['LDAP_USER_CONFIG_PASS']
	else:
		print('Ошибка. Переменные окружения LDAP_USER_CONFIG и LDAP_USER_CONFIG_PASS не опредлены')
		sys.exit(-1)

	# Function

	if namespace.list:
		try:
			for item in schema_list():
				print item
		except ValueError as e:
			print e
			sys.exit(-1)

		sys.exit(0)

	if namespace.insert != None:
		fname = namespace.insert

		if not os.path.isfile(fname) and not os.path.isabs(fname):
			fname = os.path.join(CORE_BASE_PATH_SCHEMES, fname)

		try:
			schema_insert(fname)
		except ValueError as e:
			print e
			sys.exit(-1)

		sys.exit(0)

	if namespace.modify != None:
		fname = namespace.modify

		if not os.path.isfile(fname) and not os.path.isabs(fname):
			fname = os.path.join(CORE_BASE_PATH_SCHEMES, fname)

		try:
			schema_modify(fname)
		except ValueError as e:
			print 'Error'
			print e
			sys.exit(-1)

		sys.exit(0)
