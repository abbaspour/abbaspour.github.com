/^attributetype.\+nisNetgroupTriple/,/)/c\
attributetype ( 1.3.6.1.1.1.1.14 NAME 'nisNetgroupTriple'\
	DESC 'Netgroup triple'\
	EQUALITY caseExactIA5Match\
	SUBSTR caseIgnoreIA5SubstringsMatch\
	SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )
/^attributetype ( 1.3.6.1.1.1.1.3 NAME 'homeDirectory'/c\
attributetype ( 1.3.6.1.1.1.1.3 NAME ('homeDirectory' 'unixHomeDirectory')
