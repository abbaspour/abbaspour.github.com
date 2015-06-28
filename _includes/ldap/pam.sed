# sed commands to update /etc/pam.conf when switching to ldapclient central authentication
/^login	auth required		pam_unix_auth.so.1/c\
# centeral auth: changing required to binding, adding pam_ldap\
login	auth binding		pam_unix_auth.so.1  server_policy\
login	auth required 		pam_ldap.so.1 try_first_pass
/^other	auth required		pam_unix_auth.so.1/c\
# central auth: changing required to sufficient, adding pam_ldap\
other	auth sufficient		pam_unix_auth.so.1\
other	auth required		pam_ldap.so.1
/^other	account required	pam_unix_account.so.1/a\
# central auth: adding pam_ldap and pam_list\
#other	account required  	pam_list.so.1 allow=\/etc\/user.allow\
other	account sufficient 	pam_ldap.so.1
#/^passwd	auth required		pam_passwd_auth.so.1/a\
#passwd	auth required 		pam_ldap.so.1
